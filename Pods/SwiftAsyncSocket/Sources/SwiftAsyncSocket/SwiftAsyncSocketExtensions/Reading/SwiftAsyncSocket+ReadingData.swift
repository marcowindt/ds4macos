//
//  SwiftAsyncSocket+ReadingData.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2018/12/18.
//  Copyright © 2018 chouheiwa. All rights reserved.
//

import Foundation
// MARK: - ReadingData
extension SwiftAsyncSocket {
    func doReadData() {
        guard let (hasBytesAvailable, estimatedBytesAvailable) = guardCanRead() else { return }

        var done = false
        var totalBytesReadForCurrentRead = 0

        guard let currentRead = currentRead as? SwiftAsyncReadPacket else {
            assert(false, "Buffer can not be cast because baseAddress is nil")
            return
        }
        do {
            // STEP 1 - READ FROM PREBUFFER
            try readFromPreBuffer(done: &done,
                                  totalBytesReadForCurrentRead: &totalBytesReadForCurrentRead,
                                  currentRead: currentRead)
            // STEP 2 - READ FROM SOCKET
            var (socketEOF, waiting) = try readFromSocket(totalBytesReadForCurrentRead: &totalBytesReadForCurrentRead,
                                                          hasBytesAvailable: hasBytesAvailable,
                                                          done: &done,
                                                          estimatedBytesAvailable: estimatedBytesAvailable)

            validDone(done: &done,
                      socketEOF: socketEOF,
                      currentRead: currentRead,
                      totalBytesReadForCurrentRead: totalBytesReadForCurrentRead)

            if !done && totalBytesReadForCurrentRead > 0 {
                waiting = true

                delegateQueue?.async {
                    self.delegate?.socket(self,
                                          didReadParticalDataOf: UInt(totalBytesReadForCurrentRead),
                                          with: currentRead.tag)
                }
            }

            if socketEOF {
                doReadEOF()
            } else if waiting && !isUsingCFStreamForTLS {
                resumeReadSource()
            }
        } catch let err as SwiftAsyncSocketError {
            validDone(done: &done,
                      error: err,
                      currentRead: currentRead,
                      totalBytesReadForCurrentRead: totalBytesReadForCurrentRead)
            return
        } catch {
            fatalError("\(error)")
        }
    }

    private func guardCanRead() -> (Bool, Int)? {
        guard currentRead != nil && !flags.contains(.readsPaused) else {

            if flags.contains(.isSecure) {
                flushSSLBuffers()
            }

            guard !isUsingCFStreamForTLS else { return nil }

            if socketFDBytesAvailable > 0 {
                suspendReadSource()
            }

            return nil
        }

        let (hasBytesAvailable, estimatedBytesAvailable) = getBytesCountAndAvailable()

        guard hasBytesAvailable || preBuffer.availableBytes != 0 else {
            // No data available to read.
            if !isUsingCFStreamForTLS {
                // Need to wait for readSource to fire and notify us of
                // available data in the socket's internal read buffer.
                resumeReadSource()
            }

            return nil
        }

        guard !flags.contains(.startingReadTLS) else {
            // The readQueue is waiting for SSL/TLS handshake to complete.
            guard flags.contains(.startingWritingTLS) else {
                // We are still waiting for the writeQueue to drain and start the SSL/TLS process.
                // We now know data is available to read.
                guard !isUsingCFStreamForTLS else { return nil }
                // Suspend the read source or else it will continue to fire nonstop.
                suspendReadSource()

                return nil
            }
            guard isUsingSecureTransportForTLS && lastSSLHandshakeError == errSSLWouldBlock else { return nil }
            // We are in the process of a SSL Handshake.
            // We were waiting for incoming data which has just arrived.
            ssl_continueSSLHandshake()

            return nil
        }

        return (hasBytesAvailable, estimatedBytesAvailable)
    }

    private func getBytesCountAndAvailable() -> (Bool, Int) {
        guard !isUsingCFStreamForTLS else {
            #if os(iOS)
            guard let readStream = readStream else {
                assert(false, SwiftAsyncSocketAssertError.stream.description)
                return (false, 0)
            }
            let hasBytesAvailable = (flags.contains(.secureSocketHasBytesAvailable) &&
                CFReadStreamHasBytesAvailable(readStream))
            return (hasBytesAvailable, 0)
            #else
            return (false, 0)
            #endif
        }
        var estimatedBytesAvailable = Int(socketFDBytesAvailable)

        if flags.contains(.isSecure) {
            guard let sslContext = sslContext, let sslPreBuffer = sslPreBuffer else {
                assert(false, SwiftAsyncSocketAssertError.secureError.description)
                return (false, 0)
            }

            estimatedBytesAvailable += sslPreBuffer.availableBytes

            var sslInternalBufSize = 0

            SSLGetBufferedReadSize(sslContext, &sslInternalBufSize)

            estimatedBytesAvailable += sslInternalBufSize
        }

        return ((estimatedBytesAvailable > 0), estimatedBytesAvailable)
    }

    private func readFromPreBuffer(done: inout Bool,
                                   totalBytesReadForCurrentRead: inout Int,
                                   currentRead: SwiftAsyncReadPacket) throws {
        guard preBuffer.availableBytes > 0 else { return }
        // There are 3 types of read packets:
        //
        // 1) Read all available data.
        // 2) Read a specific length of data.
        // 3) Read up to a particular terminator.
        var bytesToCopy: UInt

        if currentRead.terminatorData != nil {
            (bytesToCopy, done) = currentRead.readLengthForTerminator(with: preBuffer)
        } else {
            bytesToCopy = currentRead.readLength(for: UInt(preBuffer.availableBytes))
        }
        currentRead.ensureCapacity(for: bytesToCopy)

        let length = Int(currentRead.startOffset + currentRead.bytesDone)

        let mutBuffer: UnsafeMutablePointer<UInt8> = currentRead.buffer.convertMutable(offset: length)

        memcpy(mutBuffer, preBuffer.readPointer, Int(bytesToCopy))

        preBuffer.didRead(size_t(bytesToCopy))

        currentRead.bytesDone += bytesToCopy

        totalBytesReadForCurrentRead += Int(bytesToCopy)

        if let readLength = currentRead.readLength, (readLength > 0) {
            done = currentRead.bytesDone == readLength
        } else if currentRead.terminatorData != nil {
            // Read type #3 - read up to a terminator
            // Our 'done' variable was updated via the readLengthForTermWithPreBuffer:found: method
            if let maxlength = currentRead.maxLength, (!done && maxlength > 0) {
                // We're not done and there's a set maxLength.
                // Have we reached that maxLength yet?
                throw SwiftAsyncSocketError.readMaxedOut
            }
        } else {
            // Read type #1 - read all available data
            //
            // We're done as soon as
            // - we've read all available data (in prebuffer and socket)
            // - we've read the maxLength of read packet.
            if let maxlength = currentRead.maxLength, (maxlength > 0 && (currentRead.bytesDone == maxlength)) {
                done = true
            }
        }

    }

    private func readFromSocket(totalBytesReadForCurrentRead: inout Int,
                                hasBytesAvailable: Bool,
                                done: inout Bool,
                                estimatedBytesAvailable: Int) throws -> (Bool, Bool) {
        var socketEOF = flags.contains(.hasReadEOF)

        var waiting = !done && !socketEOF && !hasBytesAvailable
        guard let currentRead = currentRead as? SwiftAsyncReadPacket else {
            fatalError("Invalid logic")
        }

        guard !done && !socketEOF && hasBytesAvailable else { return (socketEOF, waiting) }

        assert(preBuffer.availableBytes == 0, "Invalid logic")

        var readIntoPreBuffer = false
        var bytesRead = 0

        let buffer = try doReadDataAllReadFunction(bytesRead: &bytesRead, waiting: &waiting,
                                                   socketEOF: &socketEOF,
                                                   readIntoPreBuffer: &readIntoPreBuffer,
                                                   estimatedBytesAvailable: estimatedBytesAvailable)

        guard bytesRead > 0 else { return (socketEOF, waiting) }

        guard !doReadDataCanReadLength(readIntoPreBuffer: readIntoPreBuffer,
                                       totalBytesReadForCurrentRead: &totalBytesReadForCurrentRead,
                                       bytesRead: bytesRead,
                                       done: &done) else {
                                    return (socketEOF, waiting)}

        guard try !doReadDataHaveTerminator(readIntoPreBuffer: readIntoPreBuffer,
                                            totalBytesReadForCurrentRead: &totalBytesReadForCurrentRead,
                                            bytesRead: bytesRead,
                                            done: &done,
                                            buffer: buffer) else {
            return (socketEOF, waiting)
        }

        doReadDataOtherAction(readIntoPreBuffer: readIntoPreBuffer,
                              bytesRead: bytesRead)

        currentRead.bytesDone += UInt(bytesRead)
        totalBytesReadForCurrentRead += bytesRead

        done = true

        return (socketEOF, waiting)
    }

    private func doReadDataCanReadLength(readIntoPreBuffer: Bool,
                                         totalBytesReadForCurrentRead: inout Int,
                                         bytesRead: Int,
                                         done: inout Bool) -> Bool {
        guard let currentRead = currentRead as? SwiftAsyncReadPacket,
            let readLength = currentRead.readLength,
            (readLength > 0) else { return false }

        assert(!readIntoPreBuffer, "Invalid logic")

        currentRead.bytesDone += UInt(bytesRead)
        totalBytesReadForCurrentRead += bytesRead

        done = currentRead.bytesDone == readLength

        return true
    }

    private func doReadDataHaveTerminator(readIntoPreBuffer: Bool,
                                          totalBytesReadForCurrentRead: inout Int,
                                          bytesRead: Int,
                                          done: inout Bool,
                                          buffer: UnsafeMutablePointer<UInt8>) throws -> Bool {
        guard let currentRead = currentRead as? SwiftAsyncReadPacket else {
            return false
        }
        guard currentRead.terminatorData != nil else {
            return false
        }

        if readIntoPreBuffer {
            preBuffer.didWrite(bytesRead)

            var bytesToCopy: UInt

            (bytesToCopy, done) = currentRead.readLengthForTerminator(with: preBuffer)

            currentRead.ensureCapacity(for: bytesToCopy)

            let length = Int(currentRead.startOffset + currentRead.bytesDone)

            let readBuf: UnsafeMutablePointer<UInt8> = currentRead.buffer.convertMutable(offset: length)

            memcpy(readBuf, preBuffer.readPointer, Int(bytesToCopy))

            preBuffer.didRead(size_t(bytesToCopy))

            currentRead.bytesDone += bytesToCopy

            totalBytesReadForCurrentRead += Int(bytesToCopy)
        } else {
            let overflow = currentRead.searchForTerminator(afterPrebuffering: bytesRead)

            if overflow == 0 {
                // Perfect match!
                // Every byte we read stays in the read buffer,
                // and the last byte we read was the last byte of the term.
                currentRead.bytesDone += UInt(bytesRead)
                totalBytesReadForCurrentRead += bytesRead
                done = true
            } else if overflow > 0 {
                // The term was found within the data that we read,
                // and there are extra bytes that extend past the end of the term.
                // We need to move these excess bytes out of the read packet and into the prebuffer.
                let underflow =  bytesRead - overflow

                // Copy excess data into preBuffer

                preBuffer.ensureCapacityForWrite(capacity: overflow)

                let overflowBuffer = buffer + underflow

                memcpy(preBuffer.writePointer, overflowBuffer, overflow)

                preBuffer.didWrite(overflow)

                // Note: The completeCurrentRead method will trim the buffer for us.

                currentRead.bytesDone += UInt(underflow)
                totalBytesReadForCurrentRead += underflow
                done = true

            } else {
                // The term was not found within the data that we read.
                currentRead.bytesDone += UInt(bytesRead)
                totalBytesReadForCurrentRead += bytesRead

                done = false
            }
        }

        if let maxLength = currentRead.maxLength, (!done && maxLength > 0) {
            // We're not done and there's a set maxLength.
            // Have we reached that maxLength yet?
            if currentRead.bytesDone >= maxLength {
                throw SwiftAsyncSocketError.readMaxedOut
            }
        }

        return true
    }

    private func doReadDataOtherAction(readIntoPreBuffer: Bool,
                                       bytesRead: Int) {
        guard let currentRead = currentRead as? SwiftAsyncReadPacket else {
            fatalError("Invild Logic")
        }
        // Read type #1 - read all available data
        guard readIntoPreBuffer else {return}
        // We just read a chunk of data into the preBuffer
        preBuffer.didWrite(bytesRead)
        // Now copy the data into the read packet.
        //
        // Recall that we didn't read directly into the packet's buffer to avoid
        // over-allocating memory since we had no clue how much data was available to be read.
        //
        // Ensure there's room on the read packet's buffer
        currentRead.ensureCapacity(for: UInt(bytesRead))
        let length = Int(currentRead.startOffset + currentRead.bytesDone)

        let readBuf: UnsafeMutablePointer<UInt8> = currentRead.buffer.convertMutable(offset: length)

        memcpy(readBuf, preBuffer.readPointer, bytesRead)
        // Remove the copied bytes from the prebuffer
        preBuffer.didRead(bytesRead)
    }

    private func validDone(done: inout Bool,
                           error: SwiftAsyncSocketError? = nil,
                           socketEOF: Bool = false,
                           currentRead: SwiftAsyncReadPacket,
                           totalBytesReadForCurrentRead: Int) {
        if !done && ((currentRead.readLength ?? 0) == 0) && currentRead.terminatorData == nil {
            // Read type #1 - read all available data
            //
            // We might arrive here if we read data from the prebuffer but not from the socket.
            done = (totalBytesReadForCurrentRead > 0)
        }
        if done {
            completeCurrentRead()

            if error == nil && (!socketEOF || preBuffer.availableBytes > 0) {
                maybeDequeueRead()
            }
        }
        guard let error = error else { return }
        closeSocket(error: error)
    }
}
