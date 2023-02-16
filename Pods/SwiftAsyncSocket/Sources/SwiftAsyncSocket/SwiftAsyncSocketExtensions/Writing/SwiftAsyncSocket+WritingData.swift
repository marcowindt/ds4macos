//
//  SwiftAsyncSocket+WritingData.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2018/12/18.
//  Copyright © 2018 chouheiwa. All rights reserved.
//

import Foundation

extension SwiftAsyncSocket {
    func doWriteData() {
        guard let currentWrite = currentWrite as? SwiftAsyncWritePacket else {
            assert(false, "Invild logic")
            return}

        let writeData = currentWrite.buffer

        guard guardDataCanWrite() else { return }

        var waiting: Bool = false

        var bytesWritten = 0

        var function = rawWrite(bytesWritten:waiting:currentWrite:writeData:)

        if flags.contains(.isSecure) {
            function = securityWrite(bytesWritten:waiting:currentWrite:writeData:)
        }

        do {
            try function(&bytesWritten,
                         &waiting,
                         currentWrite,
                         writeData)
        } catch let err as SwiftAsyncSocketError {
            closeSocket(error: err)
            return
        } catch let err {
            fatalError("\(err)")
        }

        if waiting {
            flags.remove(.canAcceptBytes)

            if !isUsingCFStreamForTLS {
                resumeWriteSource()
            }
        }

        var done = false

        if bytesWritten > 0 {
            currentWrite.bytesDone += UInt(bytesWritten)

            done = currentWrite.bytesDone == writeData.count
        }

        guard !done else {
            // We have already complete write
            completeCurrentWrite()

            socketQueue.async { self.maybeDequeueWrite() }
            return
        }
        // not done
        guard !waiting else { return }
        // Not waiting here
        flags.remove(.canAcceptBytes)

        if !isUsingCFStreamForTLS { resumeWriteSource() }

        guard bytesWritten > 0 else { return }
        // We're not done with the entire write, but we have written some bytes
        delegateQueue?.async {
            self.delegate?.socket(self, didWriteParticalDataOf: UInt(bytesWritten), with: currentWrite.tag)
        }
    }

    private func guardDataCanWrite() -> Bool {
        guard !flags.contains(.writePaused) else {
            // Unable to write at this time
            guard !isUsingCFStreamForTLS else {
                // CFWriteStream only fires once when there is available data.
                // It won't fire again until we've invoked CFWriteStreamWrite.
                return false}

            if flags.contains(.canAcceptBytes) { suspendWriteSource() }
            return false
        }

        guard flags.contains(.canAcceptBytes) else {
            // No space available to write.
            guard !isUsingCFStreamForTLS else {
                // Need to wait for writeSource to fire and notify us of
                // available space in the socket's internal write buffer.
                return false
            }

            resumeWriteSource()
            return false
        }

        guard !flags.contains(.startingWritingTLS) else {
            // The writeQueue is waiting for SSL/TLS handshake to complete.
            guard flags.contains(.startingReadTLS) else {
                // We are still waiting for the readQueue to drain and start the SSL/TLS process.
                // We now know we can write to the socket.
                guard !isUsingCFStreamForTLS else { return false }
                // Suspend the write source or else it will continue to fire nonstop.
                suspendWriteSource()

                return false
            }

            guard isUsingSecureTransportForTLS && (lastSSLHandshakeError == errSSLWouldBlock) else { return false }

            // We are in the process of a SSL Handshake.
            // We were waiting for available space in the socket's internal OS buffer to continue writing.
            ssl_continueSSLHandshake()

            return false
        }

        return true
    }

    private func securityWriteForCFStream(bytesWritten: inout Int,
                                          waiting: inout Bool,
                                          currentWrite: SwiftAsyncWritePacket,
                                          writeData: Data) throws {
        #if os(iOS)
        let buffer: UnsafePointer<UInt8> = writeData.convert(offset: Int(currentWrite.bytesDone))

        let bytesToWrite = min(UInt(writeData.count - Int(currentWrite.bytesDone)), SIZE_MAX)

        let result = CFWriteStreamWrite(writeStream, buffer, CFIndex(bytesToWrite))

        guard result >= 0 else {
            throw SwiftAsyncSocketError.cfError(error: CFWriteStreamCopyError(writeStream))
        }

        bytesWritten = result
        // We always set waiting to true in this scenario.
        // CFStream may have altered our underlying socket to non-blocking.
        // Thus if we attempt to write without a callback, we may end up blocking our queue.
        waiting = true
        #endif
    }

    private func securityWrite(bytesWritten: inout Int,
                               waiting: inout Bool,
                               currentWrite: SwiftAsyncWritePacket,
                               writeData: Data) throws {
        guard !isUsingCFStreamForTLS else {
            try securityWriteForCFStream(bytesWritten: &bytesWritten,
                                         waiting: &waiting,
                                         currentWrite: currentWrite,
                                         writeData: writeData)
            return
        }

        // We're going to use the SSLWrite function.
        //
        // OSStatus SSLWrite(SSLContextRef context, const void *data, size_t dataLength, size_t *processed)
        //
        // Parameters:
        // context     - An SSL session context reference.
        // data        - A pointer to the buffer of data to write.
        // dataLength  - The amount, in bytes, of data to write.
        // processed   - On return, the length, in bytes, of the data actually written.
        //
        // It sounds pretty straight-forward,
        // but there are a few caveats you should be aware of.
        //
        // The SSLWrite method operates in a non-obvious (and rather annoying) manner.
        // According to the documentation:
        //
        //   Because you may configure the underlying connection to operate in a non-blocking manner,
        //   a write operation might return errSSLWouldBlock, indicating that less data than requested
        //   was actually transferred. In this case, you should repeat the call to SSLWrite until some
        //   other result is returned.
        //
        // This sounds perfect, but when our SSLWriteFunction returns errSSLWouldBlock,
        // then the SSLWrite method returns (with the proper errSSLWouldBlock return value),
        // but it sets processed to dataLength !!
        //
        // In other words, if the SSLWrite function doesn't completely write all the data we tell it to,
        // then it doesn't tell us how many bytes were actually written. So, for example, if we tell it to
        // write 256 bytes then it might actually write 128 bytes, but then report 0 bytes written.
        //
        // You might be wondering:
        // If the SSLWrite function doesn't tell us how many bytes were written,
        // then how in the world are we supposed to update our parameters (buffer & bytesToWrite)
        // for the next time we invoke SSLWrite?
        //
        // The answer is that SSLWrite cached all the data we told it to write,
        // and it will push out that data next time we call SSLWrite.
        // If we call SSLWrite with new data, it will push out the cached data first, and then the new data.
        // If we call SSLWrite with empty data, then it will simply push out the cached data.
        //
        // For this purpose we're going to break large writes into a series of smaller writes.
        // This allows us to report progress back to the delegate.
        var result: OSStatus

        var hasNewDataToWrite = true

        guard let sslContext = sslContext else {fatalError("Logic Error")}

        if sslWriteCachedLength > 0 {
            var processed = 0

            result = Security.SSLWrite(sslContext, nil, 0, &processed)

            guard result != noErr else {
                if result !=  errSSLWouldBlock {
                    throw SwiftAsyncSocketError.sslError(code: result)
                }
                waiting = true

                return
            }

            bytesWritten = sslWriteCachedLength
            sslWriteCachedLength = 0
            // We've written all data for the current write.
            hasNewDataToWrite = writeData.count != (Int(currentWrite.bytesDone) + bytesWritten)
        }

        guard hasNewDataToWrite else { return }

        var buffer: UnsafePointer<UInt8> = writeData.convert(offset: Int(currentWrite.bytesDone) + bytesWritten)

        let bytesToWrite = writeData.count - Int(currentWrite.bytesDone) - bytesWritten
        // NSUInteger may be bigger than size_t (write param 3)
        var bytesRemaining = bytesToWrite

        var keepLooping = true

        let sslMaxBytesToWrite = 32_768

        while keepLooping {
            let sslBytesToWrite = min(bytesRemaining, sslMaxBytesToWrite)

            var sslBytesWritten = 0

            result = Security.SSLWrite(sslContext, buffer, sslBytesToWrite, &sslBytesWritten)

            guard result == noErr else {
                if result != errSSLWouldBlock {
                    throw SwiftAsyncSocketError.sslError(code: result)
                }
                waiting = true
                sslWriteCachedLength = sslBytesToWrite
                return
            }
            buffer += sslBytesWritten
            bytesWritten += sslBytesWritten
            bytesRemaining -= sslBytesWritten

            keepLooping = bytesRemaining > 0
        }
    }

    private func rawWrite(bytesWritten: inout Int,
                          waiting: inout Bool,
                          currentWrite: SwiftAsyncWritePacket,
                          writeData: Data) throws {
        //
        // Writing data directly over raw socket
        //
        let buffer: UnsafePointer<UInt8> = writeData.convert(offset: Int(currentWrite.bytesDone))

        var bytesToWrite = writeData.count - Int(currentWrite.bytesDone)

        if bytesToWrite > SIZE_MAX {
            bytesToWrite = Int(SIZE_MAX)
        }

        let result = Darwin.write(currentSocketFD, buffer, bytesToWrite)

        guard result >= 0 else {
            if errno != EWOULDBLOCK {
                throw SwiftAsyncSocketError.errno(code: errno, reason: "Error in write() function")
            }
            waiting = true
            return
        }

        bytesWritten = result
    }

    private func completeCurrentWrite() {
        guard let currentWrite = currentWrite as? SwiftAsyncWritePacket else {
            assert(false, "Invid logic")
            fatalError("Invid logic")
        }

        delegateQueue?.async {
            self.delegate?.socket(self, didWriteDataWith: currentWrite.tag)
        }

        endCurrentWrite()
    }
}
