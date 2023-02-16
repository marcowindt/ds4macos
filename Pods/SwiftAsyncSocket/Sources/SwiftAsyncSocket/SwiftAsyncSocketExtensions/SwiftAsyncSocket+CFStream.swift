//
//  SwiftAsyncSocket+CFStream.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2018/12/14.
//  Copyright © 2018 chouheiwa. All rights reserved.
//

import Foundation

// MARK: - CFFoundation Relationship
extension SwiftAsyncSocket {
    #if os(iOS)

    func cfFinishSSLHandShake() {
        guard flags.contains([.startingReadTLS, .startingWritingTLS]) else {
            return
        }

        flags.remove([.startingReadTLS, .startingWritingTLS])

        flags.insert(.isSecure)

        delegateQueue?.async {
            self.delegate?.socketDidSecure(self)
        }

        endCurrentRead()
        endCurrentWrite()
    }

    func cfAbortSSLHandshake(_ error: SwiftAsyncSocketError) {
        guard flags.contains([.startingReadTLS, .startingWritingTLS]) else {
            return
        }

        flags.remove([.startingReadTLS, .startingWritingTLS])
        closeSocket(error: error)
    }

    func cf_startTLS() {
        guard preBuffer.availableBytes == 0 else {
            self.closeSocket(error: SwiftAsyncSocketError(msg:
                "Invalid TLS transition. Handshake has already been read from socket."))
            return
        }
        suspendReadSource()
        suspendWriteSource()

        socketFDBytesAvailable = 0
        flags.remove([.canAcceptBytes, .secureSocketHasBytesAvailable])

        flags.insert(.isUsingCFStreamForTLS)

        guard createReadWriteStream() else {
            closeSocket(error: SwiftAsyncSocketError(msg: "Error in CFStreamCreatePairWithSocket"))
            return
        }

        guard registerForStreamCallbacks(including: true) else {
            closeSocket(error: SwiftAsyncSocketError(msg: "Error in CFStreamSetClient"))
            return
        }

        guard addStreamsToRunloop() else {
            closeSocket(error: SwiftAsyncSocketError(msg: "Error in CFStreamScheduleWithRunLoop"))
            return
        }

        guard let currentRead = currentRead as? SwiftAsyncSpecialPacket,
            (currentWrite as? SwiftAsyncSpecialPacket != nil)  else {
            assert(false, "Invalid packet for startTLS")
            return
        }
        // Next To Do
        let tlsSettings = currentRead.tlsSettings.toDictionary() as CFDictionary

        // Getting an error concerning kCFStreamPropertySSLSettings ?
        // You need to add the CFNetwork framework to your iOS application.

        let readStreamPropertyEnable = CFReadStreamSetProperty(readStream,
                                                               CFStreamPropertyKey(kCFStreamPropertySSLSettings),
                                                               tlsSettings)
        let writeStreamPropertyEnable = CFWriteStreamSetProperty(writeStream,
                                                                 CFStreamPropertyKey(kCFStreamPropertySSLSettings),
                                                                 tlsSettings)
        guard readStreamPropertyEnable && writeStreamPropertyEnable else {
            // For some reason, starting around the time of iOS 4.3,
            // the first call to set the kCFStreamPropertySSLSettings will return true,
            // but the second will return false.
            //
            // Order doesn't seem to matter.
            // So you could call CFReadStreamSetProperty and then CFWriteStreamSetProperty,
            // or you could reverse the order.
            // Either way, the first call will return true, and the second returns false.
            //
            // Interestingly, this doesn't seem to affect anything.
            // Which is not altogether unusual, as the documentation seems to suggest that (for many settings)
            // setting it on one side of the stream automatically sets it for the other side of the stream.
            //
            // Although there isn't anything in the documentation to suggest that the second attempt would fail.
            //
            // Furthermore, this only seems to affect streams that are negotiating a security upgrade.
            // In other words, the socket gets connected, there is some back-and-forth communication over the unsecure
            // connection, and then a startTLS is issued.
            // So this mostly affects newer protocols (XMPP, IMAP) as opposed to older protocols (HTTPS).
            closeSocket(error: SwiftAsyncSocketError(msg: "Error in CFStreamSetProperty"))
            return
        }

        guard openStreams() else {
            closeSocket(error: SwiftAsyncSocketError(msg: "Error in CFStreamOpen"))
            return
        }
    }

    func openStreams() -> Bool {
        assert(DispatchQueue.getSpecific(key: queueKey) != nil, "Must be dispatched on socketQueue")
        guard let readStream = readStream, let writeStream = writeStream else {
            assert(false, "Read/Write stream is null")
            return false
        }

        let readStatus = CFReadStreamGetStatus(readStream)
        let writeStatus = CFWriteStreamGetStatus(writeStream)

        if readStatus == .notOpen || writeStatus == .notOpen {
            let readOpen = CFReadStreamOpen(readStream)
            let writeOpen = CFWriteStreamOpen(writeStream)

            guard readOpen && writeOpen else { return false }
        }

        return true
    }

    #endif
}

// MARK: - ReadWriteStream
#if os(iOS)
extension SwiftAsyncSocket {
    func createReadWriteStream() -> Bool {
        assert(DispatchQueue.getSpecific(key: queueKey) != nil,
               SwiftAsyncSocketAssertError.socketQueueAction.description)

        guard readStream == nil && writeStream == nil else {return true}

        var currentSocketFD: Int32 = SwiftAsyncSocketKeys.socketNull

        if socket4FD != SwiftAsyncSocketKeys.socketNull { currentSocketFD = socket4FD }

        if socket6FD != SwiftAsyncSocketKeys.socketNull { currentSocketFD = socket6FD }

        if socketUN != SwiftAsyncSocketKeys.socketNull { currentSocketFD = socketUN }
        // Cannot create streams without a file descriptor
        guard currentSocketFD != SwiftAsyncSocketKeys.socketNull else {return false}
        // Cannot create streams until file descriptor is connected
        guard self.isConnected else {return false}
        var localReadStream: Unmanaged<CFReadStream>?
        var localWriteStream: Unmanaged<CFWriteStream>?
        CFStreamCreatePairWithSocket(nil, CFSocketNativeHandle(currentSocketFD), &localReadStream, &localWriteStream)

        guard let totalReadStream = localReadStream?.takeRetainedValue() else {
            if let totalWriteStream = localWriteStream?.takeRetainedValue() {
                CFWriteStreamClose(totalWriteStream)
            }
            return false
        }

        guard let totalWriteStream = localWriteStream?.takeRetainedValue() else {
            CFReadStreamClose(totalReadStream)
            return false
        }

        readStream = totalReadStream
        writeStream = totalWriteStream

        return true
    }

    func registerForStreamCallbacks(including canReadWrite: Bool) -> Bool {
        assert(DispatchQueue.getSpecific(key: queueKey) != nil,
               SwiftAsyncSocketAssertError.socketQueueAction.description)
        guard let readStream = readStream else {
            assert(false, SwiftAsyncSocketAssertError.stream.description)
            return false
        }

        guard let writeStream = writeStream else {
            assert(false, SwiftAsyncSocketAssertError.stream.description)
            return false
        }

        streamContext.version = 0

        var `self` = self

        streamContext.info = UnsafeMutableRawPointer(&self)

        streamContext.release = nil

        streamContext.retain = nil

        streamContext.copyDescription = nil

        var readStreamEvents: CFStreamEventType = [.errorOccurred, .endEncountered]

        if canReadWrite {readStreamEvents.insert(.hasBytesAvailable)}

        guard register(readStream: readStream, readStreamEvents: readStreamEvents) else {
            return false
        }
        var writeStreamEvents: CFStreamEventType = [.errorOccurred, .endEncountered]

        if canReadWrite {writeStreamEvents.insert(.canAcceptBytes)}

        return register(writeStream: writeStream, writeStreamEvents: writeStreamEvents)
    }

    private func register(readStream: CFReadStream, readStreamEvents: CFStreamEventType) -> Bool {
        return CFReadStreamSetClient(readStream, readStreamEvents.rawValue, { (readStreamInBlock, types, pointer) in
            guard let `self` = pointer?.assumingMemoryBound(to: SwiftAsyncSocket.self).pointee else {
                return
            }

            guard let totalReadStream = self.readStream,
                (totalReadStream == readStreamInBlock) else {return}

            if types.contains(.hasBytesAvailable) {
                self.socketQueue.async {
                    if self.flags.contains([.startingReadTLS, .startingWritingTLS]) {
                        guard CFReadStreamHasBytesAvailable(totalReadStream) else {return}

                        self.flags.insert(.secureSocketHasBytesAvailable)
                        self.cfFinishSSLHandShake()
                    } else {
                        self.flags.insert(.secureSocketHasBytesAvailable)

                        self.doReadData()
                    }
                }
            } else {
                var error: SwiftAsyncSocketError = .connectionClosedError

                if let itemErr = CFReadStreamCopyError(readStreamInBlock) {
                    error = SwiftAsyncSocketError.cfError(error: itemErr)
                }

                self.socketQueueDo(sync: false, {
                    if self.flags.contains([.startingReadTLS, .startingWritingTLS]) {
                        self.cfAbortSSLHandshake(error)
                    } else {
                        self.closeSocket(error: error)
                    }
                })
            }
        }, &streamContext)
    }

    private func register(writeStream: CFWriteStream, writeStreamEvents: CFStreamEventType) -> Bool {
        return CFWriteStreamSetClient(writeStream, writeStreamEvents.rawValue, { (writeStreamInBlock, types, pointer) in
            guard let `self` = pointer?.assumingMemoryBound(to: SwiftAsyncSocket.self).pointee else {
                return
            }

            guard let totalWriteStream = self.writeStream,
                (totalWriteStream == writeStreamInBlock) else {return}

            if types.contains(.canAcceptBytes) {
                self.socketQueue.async {
                    if self.flags.contains([.startingReadTLS, .startingWritingTLS]) {
                        guard CFWriteStreamCanAcceptBytes(totalWriteStream) else {return}

                        self.flags.insert(.canAcceptBytes)
                        self.cfFinishSSLHandShake()
                    } else {
                        self.flags.insert(.canAcceptBytes)

                        self.doWriteData()
                    }
                }
            } else {
                var error: SwiftAsyncSocketError = .connectionClosedError

                if let itemErr = CFWriteStreamCopyError(writeStreamInBlock) {
                    error = SwiftAsyncSocketError.cfError(error: itemErr)
                }

                self.socketQueueDo(sync: false, {
                    if self.flags.contains([.startingReadTLS, .startingWritingTLS]) {
                        self.cfAbortSSLHandshake(error)
                    } else {
                        self.closeSocket(error: error)
                    }
                })
            }
        }, &streamContext)
    }

    func addStreamsToRunloop() -> Bool {
        assert(DispatchQueue.getSpecific(key: queueKey) != nil,
               SwiftAsyncSocketAssertError.socketQueueAction.description)

        guard readStream != nil else {
            assert(false, SwiftAsyncSocketAssertError.stream.description)
            return false
        }

        guard writeStream != nil else {
            assert(false, SwiftAsyncSocketAssertError.stream.description)
            return false
        }

        guard !flags.contains(.addedStreamsToRunLoop) else {
            return true
        }

        var result = false

        SwiftAsyncThread.default.startIfNeeded()

        SwiftAsyncThread.default.setupQueue.sync {
            guard let thread = SwiftAsyncThread.default.thread else { return }

            result = true

            SwiftAsyncThread.default.perform(#selector(SwiftAsyncThread.default.scheduleCFStreams),
                                             on: thread,
                                             with: self,
                                             waitUntilDone: true)
        }
        flags.insert(.addedStreamsToRunLoop)

        return result
    }

    func removeStreamFromRunloop() {
        assert(DispatchQueue.getSpecific(key: queueKey) != nil,
               SwiftAsyncSocketAssertError.socketQueueAction.description)

        guard readStream != nil else {
            assert(false, SwiftAsyncSocketAssertError.stream.description)
            return
        }

        guard writeStream != nil else {
            assert(false, SwiftAsyncSocketAssertError.stream.description)
            return
        }

        guard flags.contains(.addedStreamsToRunLoop) else {return}

        SwiftAsyncThread.default.setupQueue.sync {
            guard let thread = SwiftAsyncThread.default.thread else { return }

            SwiftAsyncThread.default.perform(#selector(SwiftAsyncThread.default.unscheduleCFStreams(asyncSocket:)),
                                             on: thread,
                                             with: self,
                                             waitUntilDone: true)

            SwiftAsyncThread.default.stopIfNeeded()

            flags.remove(.addedStreamsToRunLoop)
        }
    }
}
#endif
