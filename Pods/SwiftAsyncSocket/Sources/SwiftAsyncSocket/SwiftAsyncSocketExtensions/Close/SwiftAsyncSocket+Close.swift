//
//  SwiftAsyncSocket+Close.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2018/12/19.
//  Copyright © 2018 chouheiwa. All rights reserved.
//

import Foundation

// MARK: - Close&End Action
extension SwiftAsyncSocket {
    func closeSocket(error: SwiftAsyncSocketError?) {
        assert(DispatchQueue.getSpecific(key: queueKey) != nil,
               SwiftAsyncSocketAssertError.socketQueueAction.description)

        endConnectTimeout()

        endCurrentRead()

        endCurrentWrite()

        preBuffer.reset()

        #if os(iOS)

        let cleanReadStream: (CFReadStream?) -> Void = { (stream) in
            guard let stream = stream else { return }

            CFReadStreamSetClient(stream, 0, nil, nil)
            CFReadStreamClose(stream)
        }

        let cleanWriteStream: (CFWriteStream?) -> Void = { (stream) in
            guard let stream = stream else { return }
            CFWriteStreamSetClient(stream, 0, nil, nil)
            CFWriteStreamClose(stream)
        }

        cleanReadStream(readStream)
        cleanWriteStream(writeStream)

        #endif

        sslPreBuffer?.reset()

        sslErrCode = noErr

        lastSSLHandshakeError = noErr

        if let sslContext = sslContext {
            // Getting a linker error here about the SSLx() functions?
            // You need to add the Security Framework to your application.

            // 如果 在SSLx()相关方法报link error
            // 你需要在你的项目中增加Security Framework

            SSLClose(sslContext)

            self.sslContext = nil
        }

        closeSocketCleanSource()

        let shouldCallDelegate = flags.contains(.started)
        let isDeallocting = flags.contains(.dealloc)

        socketFDBytesAvailable = 0
        flags = []
        sslWriteCachedLength = 0

        if shouldCallDelegate {
            if let delegate = delegate {
                let `self` = isDeallocting ? nil : self

                delegateQueue?.async {
                    delegate.socket(self, didDisconnectWith: error)
                }
            }
        }
    }

    /// Call this method to disconnect socket
    public func disconnect() {
        socketQueueDo {
            guard self.flags.contains(.started) else {
                return
            }
            self.closeSocket(error: nil)
        }
    }

    /// Socket will be close when the reading has been completed.
    public func disconnectAfterReading() {
        socketQueueDo {
            guard self.flags.contains(.started) else {
                return
            }
            self.flags.insert([.forbidReadWrites, .disconnectAfterReads])
            self.maybeClose()
        }
    }

    /// Socket will be close when all the writing has been completed.
    public func disconnectAfterWriting() {
        socketQueueDo {
            guard self.flags.contains(.started) else {
                return
            }

            self.flags.insert([.forbidReadWrites, .disconnectAfterWrites])
            self.maybeClose()
        }
    }

    /// Socket will be close when all the reading and writing have been completed.
    public func disconnectAfterReadingAndWriting() {
        socketQueueDo {
            guard self.flags.contains(.started) else {
                return
            }

            self.flags.insert([.forbidReadWrites,
                               .disconnectAfterReads,
                               .disconnectAfterWrites])
            self.maybeClose()
        }
    }

    func maybeClose() {
        assert(DispatchQueue.getSpecific(key: queueKey) != nil,
               SwiftAsyncSocketAssertError.socketQueueAction.description)

        var shouldClose = false

        if flags.contains(.disconnectAfterReads) {
            if readQueue.count == 0 && currentRead == nil {
                shouldClose = true
                if flags.contains(.disconnectAfterWrites) {
                    if writeQueue.count != 0 || currentWrite != nil {
                        shouldClose = false
                    }
                }
            }
        } else if flags.contains(.disconnectAfterWrites) {
            if writeQueue.count == 0 && currentWrite == nil {
                shouldClose = true
            }
        }
        if shouldClose {
            closeSocket(error: nil)
        }
    }

    private func closeSocketCleanSource() {
        if socket4FD != SwiftAsyncSocketKeys.socketNull {
            Darwin.close(socket4FD)
            socket4FD = SwiftAsyncSocketKeys.socketNull
        }

        if socket6FD != SwiftAsyncSocketKeys.socketNull {
            Darwin.close(socket6FD)
            socket6FD = SwiftAsyncSocketKeys.socketNull
        }

        if socketUN != SwiftAsyncSocketKeys.socketNull {
            Darwin.close(socketUN)
            socketUN = SwiftAsyncSocketKeys.socketNull
            if let socketURL = socketURL {

                let path = socketURL.path as NSString

                unlink(path.fileSystemRepresentation)
            }
        }

        accept4Source?.cancel()
        accept6Source?.cancel()
        acceptUNSource?.cancel()
        readSource?.cancel()
        writeSource?.cancel()

        socket4FD = SwiftAsyncSocketKeys.socketNull
        socket6FD = SwiftAsyncSocketKeys.socketNull
        socketUN = SwiftAsyncSocketKeys.socketNull
    }

}
