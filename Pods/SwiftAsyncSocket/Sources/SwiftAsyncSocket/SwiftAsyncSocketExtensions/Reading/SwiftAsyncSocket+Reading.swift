//
//  SwiftAsyncSocket+Reading.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2018/12/13.
//  Copyright © 2018 chouheiwa. All rights reserved.
//

import Foundation

// MARK: - Reading
extension SwiftAsyncSocket {

    func maybeDequeueRead() {
        assert(DispatchQueue.getSpecific(key: queueKey) != nil,
               SwiftAsyncSocketAssertError.socketQueueAction.description)

        guard currentRead == nil && flags.contains(.connected) else {return}

        if readQueue.count > 0 {
            currentRead = readQueue.first
            readQueue.remove(at: 0)

            if currentRead is SwiftAsyncSpecialPacket {
                flags.insert(.startingReadTLS)

                maybeStartTLS()
            } else if let currentRead = currentRead as? SwiftAsyncReadPacket {
                setupReadTimer(with: currentRead.timeout)

                doReadData()
            }
        } else if flags.contains(.disconnectAfterReads) {
            if flags.contains(.disconnectAfterWrites) {
                if writeQueue.count == 0 && currentWrite == nil {
                    closeSocket(error: nil)
                }
            } else {
                closeSocket(error: nil)
            }
        } else if flags.contains(.isSecure) {
            flushSSLBuffers()

            // Edge case:
            //
            // We just drained all data from the ssl buffers,
            // and all known data from the socket (socketFDBytesAvailable).
            //
            // If we didn't get any data from this process,
            // then we may have reached the end of the TCP stream.
            //
            // Be sure callbacks are enabled so we're notified about a disconnection.

            if preBuffer.availableBytes == 0 {
                if !isUsingCFStreamForTLS {
                    resumeReadSource()
                }
            }
        }
    }

    func flushSSLBuffers() {
        assert(flags.contains(.isSecure), SwiftAsyncSocketAssertError.secureError.description)

        guard let sslContext = sslContext, let sslPreBuffer = sslPreBuffer else {
            assert(false, SwiftAsyncSocketAssertError.secureError.description)
            return
        }

        guard preBuffer.availableBytes == 0 else {
            // Only flush the ssl buffers if the prebuffer is empty.
            // This is to avoid growing the prebuffer inifinitely large.

            // 当预缓存区是空的时候才刷新ssl缓存
            // 这种操作是为了避免预缓存区占用内存无限增长
            return
        }

        #if os(iOS)

        guard !isUsingCFStreamForTLS else {
            guard let readStream = readStream,
                (flags.contains(.secureSocketHasBytesAvailable) && CFReadStreamHasBytesAvailable(readStream))
                else { return }

            let defaultBytesToRead = 1024 * 4

            preBuffer.ensureCapacityForWrite(capacity: defaultBytesToRead)

            let result = CFReadStreamRead(readStream, preBuffer.writePointer, defaultBytesToRead)

            if result > 0 { preBuffer.didWrite(result) }

            flags.remove(.secureSocketHasBytesAvailable)

            return
        }
        // 当不使用CFStream时
        #endif

        var estimatedBytesAvailable = 0

        updateEstimatedBytesAvailable(&estimatedBytesAvailable,
                                      sslContext: sslContext,
                                      sslPreBuffer: sslPreBuffer)

        guard estimatedBytesAvailable > 0 else { return }

        var done = false

        repeat {
            // 确保空间足够
            // Make sure there's enough room in the prebuffer
            preBuffer.ensureCapacityForWrite(capacity: estimatedBytesAvailable)

            // Read data into prebuffer
            var bytesRead = 0

            let status = SSLRead(sslContext,
                                 UnsafeMutableRawPointer(preBuffer.writePointer),
                                 estimatedBytesAvailable,
                                 &bytesRead)

            if bytesRead > 0 {
                preBuffer.didWrite(bytesRead)
            }

            if status != noErr {
                done = true
            } else {
                updateEstimatedBytesAvailable(&estimatedBytesAvailable,
                                              sslContext: sslContext,
                                              sslPreBuffer: sslPreBuffer)
            }

        }while (!done && estimatedBytesAvailable > 0)
    }

    private func updateEstimatedBytesAvailable(_ estimatedBytesAvailable: inout Int,
                                               sslContext: SSLContext,
                                               sslPreBuffer: SwiftAsyncSocketBuffer) {
        estimatedBytesAvailable = Int(self.socketFDBytesAvailable) + sslPreBuffer.availableBytes

        var sslInternalBufSize = 0

        SSLGetBufferedReadSize(sslContext, &sslInternalBufSize)

        estimatedBytesAvailable += sslInternalBufSize
    }

    func doReadEOF() {
        // This method may be called more than once.
        // If the EOF is read while there is still data in the preBuffer,
        // then this method may be called continually after invocations of doReadData to see if it's time to disconnect.

        flags.insert(.hasReadEOF)

        if flags.contains(.isSecure) {
            flushSSLBuffers()
        }

        var shouldDisconnect = true
        var error: SwiftAsyncSocketError?

        if flags.contains([.startingReadTLS, .startingWritingTLS]) {
            // We received an EOF during or prior to startTLS.
            // The SSL/TLS handshake is now impossible, so this is an unrecoverable situation.

            if isUsingSecureTransportForTLS {
                error = SwiftAsyncSocketError.sslError(code: errSSLClosedAbort)
            }
        } else if flags.contains(.readSteamClosed) {
            // The preBuffer has already been drained.
            // The config allows half-duplex connections.
            // We've previously checked the socket, and it appeared writeable.
            // So we marked the read stream as closed and notified the delegate.
            //
            // As per the half-duplex contract, the socket will be closed when a write fails,
            // or when the socket is manually closed.
            shouldDisconnect = false
        } else if preBuffer.availableBytes > 0 {
            // Although we won't be able to read any more data from the socket,
            // there is existing data that has been prebuffered that we can read.

            shouldDisconnect =  false
        } else if config.contains(.allowHalfDuplexConnection) {
            var pfd: pollfd = Darwin.pollfd(fd: currentSocketFD, events: Int16(POLLOUT), revents: 0)

            Darwin.poll(&pfd, 1, 0)

            if (pfd.revents & Int16(POLLOUT)) != 0 {
                // Socket appears to still be writeable

                shouldDisconnect = false
                flags.insert(.readSteamClosed)

                // Notify the delegate that we're going half-duplex

                delegateQueue?.async {
                    self.delegate?.socketDidClosedReadStream(self)
                }
            }
        }

        guard shouldDisconnect else {
            if !isUsingCFStreamForTLS {
                suspendReadSource()
            }
            return
        }

        if error == nil {
            error = (
                isUsingSecureTransportForTLS &&
                    sslErrCode != noErr &&
                    sslErrCode != errSSLClosedGraceful) ?
                        SwiftAsyncSocketError.sslError(code: sslErrCode) :
                SwiftAsyncSocketError.connectionClosedError
        }

        closeSocket(error: error)
    }

    func completeCurrentRead() {
        guard let currentRead = currentRead as? SwiftAsyncReadPacket else {
            assert(false, "Trying to complete current read when there is no current read.")
            return
        }

        var result: Data

        if currentRead.bufferOwner {
            // We created the buffer on behalf of the user.
            // Trim our buffer to be the proper size.
            currentRead.buffer.count = Int(currentRead.bytesDone)

            result = currentRead.buffer
        } else {
            // We did NOT create the buffer.
            // The buffer is owned by the caller.
            // Only trim the buffer if we had to increase its size.
            if currentRead.buffer.count > currentRead.originBufferLength {
                let readSize = currentRead.startOffset + currentRead.bytesDone
                let origSize = currentRead.originBufferLength

                currentRead.buffer.count = Int(max(readSize, origSize))
            }
            let offset = Int(currentRead.startOffset)

            let buffer: UnsafeMutablePointer<UInt8> = currentRead.buffer.convertMutable(offset: offset)

            result = Data(bytesNoCopy: buffer, count: Int(currentRead.bytesDone), deallocator: .none)
        }

        delegateQueue?.async {
            self.delegate?.socket(self, didRead: result, with: currentRead.tag)
        }

        endCurrentRead()
    }

    func setupReadTimer(with timeOut: TimeInterval) {
        guard timeOut > 0 else { return }

        let timer = DispatchSource.makeTimerSource(flags: [], queue: socketQueue)

        timer.setEventHandler {  [weak self] in
            self?.doReadTimeout()
        }

        timer.schedule(deadline: DispatchTime.now() + timeOut, repeating: .never, leeway: .nanoseconds(0))

        timer.resume()
    }

    func doReadTimeout() {
        guard let currentRead = currentRead as? SwiftAsyncReadPacket else {
            assert(false, "doReadTimeOut need currentRead with SwiftAsyncReadPacket")
            fatalError("doReadTimeOut need currentRead with SwiftAsyncReadPacket")
        }

        flags.insert(.readsPaused)
        // This is a little bit tricky.
        // Ideally we'd like to synchronously query the delegate about a timeout extension.
        // But if we do so synchronously we risk a possible deadlock.
        // So instead we have to do so asynchronously, and callback to ourselves from within the delegate block.

        // 这个操作有点棘手
        // 理想状态下我们应该通过同步调用delegate的超时拓展
        // 但是如果我们操作是同步的，这将有操作死锁的风险
        // 所以替代方案是，我们只能异步调用，然后在delegate的回调中调用我们的操作

        guard let delegateQueue = delegateQueue, let delegate = delegate
        else {
            doReadTimeout(timeOut: 0.0)
            return
        }

        delegateQueue.async {
            let timerOutExtension = delegate.socket(self,
                                                    shouldTimeoutReadWith: currentRead.tag,
                                                    elapsed: currentRead.timeout,
                                                    bytesDone: currentRead.bytesDone) ?? 0.0
            self.socketQueue.async {
                self.doReadTimeout(timeOut: timerOutExtension)
            }
        }
    }

    private func doReadTimeout(timeOut: TimeInterval) {
        guard let currentRead = currentRead as? SwiftAsyncReadPacket, let readTimer = readTimer else { return }

        guard timeOut > 0.0 else {
            closeSocket(error: SwiftAsyncSocketError(msg: "Read Time Out!"))
            return
        }

        currentRead.timeout += timeOut

        readTimer.schedule(deadline: DispatchTime.now() + timeOut, repeating: .never, leeway: .nanoseconds(0))
    }

    func endCurrentRead() {
        readTimer?.cancel()
        readTimer = nil

        currentRead = nil
    }
}
