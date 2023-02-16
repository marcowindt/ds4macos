//
//  SwiftAsyncSocket+SSL.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2018/12/19.
//  Copyright © 2018 chouheiwa. All rights reserved.
//

import Foundation

extension SwiftAsyncSocket {
    func sslWrite(buffer: UnsafeMutableRawPointer, length: UnsafeMutablePointer<Int>) -> OSStatus {
        guard flags.contains(.canAcceptBytes) else {
            // Unable to write.
            //
            // Need to wait for writeSource to fire and notify us of
            // available space in the socket's internal write buffer.
            resumeWriteSource()

            length.pointee = 0

            return errSSLWouldBlock
        }

        let bytesToWrite = length.pointee
        var bytesWritten = 0

        var done = false
        var socketError = false

        let result = Darwin.write(currentSocketFD, buffer, bytesToWrite)

        if result < 0 {
            if errno != EWOULDBLOCK {
                socketError = true
            }

            flags.remove(.canAcceptBytes)
        } else if result == 0 {
            flags.remove(.canAcceptBytes)
        } else {
            bytesWritten = result

            done = (bytesWritten == bytesToWrite)
        }

        length.pointee = bytesWritten

        if done { return noErr }
        if socketError { return errSSLClosedAbort }

        return errSSLWouldBlock
    }

    func sslRead(buffer: UnsafeMutableRawPointer,
                 length: UnsafeMutablePointer<Int>) -> OSStatus {
        guard let sslPreBuffer = sslPreBuffer, (socketFDBytesAvailable != 0 || sslPreBuffer.availableBytes != 0) else {
            resumeReadSource()

            length.pointee = 0

            return errSSLWouldBlock
        }

        var totalBytesRead = 0
        var totalBytesLeftToBeRead = length.pointee
        //
        // STEP 1 : READ FROM SSL PRE BUFFER
        // 第一步: 从SSL缓存区读取
        //
        var done = sslReadFromPrebuffer(sslPreBuffer: sslPreBuffer,
                                        totalBytesLeftToBeRead: &totalBytesLeftToBeRead,
                                        totalBytesRead: &totalBytesRead,
                                        buffer: buffer)

        //
        // STEP 2 : READ FROM SOCKET
        // 第二步: 从socket中获取
        //
        let socketError = sslReadFromSocket(sslPreBuffer: sslPreBuffer,
                                            done: &done,
                                            totalBytesLeftToBeRead: &totalBytesLeftToBeRead,
                                            totalBytesRead: &totalBytesRead,
                                            buffer: buffer)

        length.pointee = totalBytesRead

        if done { return noErr }

        if socketError { return errSSLClosedAbort }

        return errSSLWouldBlock
    }

    func sslReadFromPrebuffer(sslPreBuffer: SwiftAsyncSocketBuffer,
                              totalBytesLeftToBeRead: inout Int,
                              totalBytesRead: inout Int,
                              buffer: UnsafeMutableRawPointer) -> Bool {
        guard sslPreBuffer.availableBytes > 0 else { return false }

        let bytesToCopy = sslPreBuffer.availableBytes > totalBytesLeftToBeRead ?
            totalBytesLeftToBeRead :
            sslPreBuffer.availableBytes

        memcpy(buffer, sslPreBuffer.readPointer, bytesToCopy)
        sslPreBuffer.didRead(bytesToCopy)

        totalBytesRead += bytesToCopy
        totalBytesLeftToBeRead -= bytesToCopy

        return totalBytesLeftToBeRead == 0
    }

    func sslReadFromSocket(sslPreBuffer: SwiftAsyncSocketBuffer,
                           done: inout Bool,
                           totalBytesLeftToBeRead: inout Int,
                           totalBytesRead: inout Int,
                           buffer: UnsafeMutableRawPointer) -> Bool {
        guard !done && socketFDBytesAvailable > 0 else {
            return false
        }
        var readIntoPreBuffer = false
        var bytesToRead = 0
        var buf: UnsafeMutableRawPointer!
        var socketError = false

        if socketFDBytesAvailable > totalBytesLeftToBeRead {
            sslPreBuffer.ensureCapacityForWrite(capacity: size_t(socketFDBytesAvailable))

            readIntoPreBuffer = true
            bytesToRead = Int(socketFDBytesAvailable)
            buf = UnsafeMutableRawPointer(sslPreBuffer.writePointer)
        } else {
            readIntoPreBuffer = false
            bytesToRead = totalBytesLeftToBeRead
            buf = buffer + totalBytesRead
        }

        let result = Darwin.read(currentSocketFD, buf, bytesToRead)

        if result < 0 {
            if errno != EWOULDBLOCK {
                socketError = true
            }

            socketFDBytesAvailable = 0
        } else if result == 0 {
            socketError = true
            socketFDBytesAvailable = 0
        } else {
            let bytesReadFromSocket = result

            if socketFDBytesAvailable > bytesReadFromSocket {
                socketFDBytesAvailable -= UInt(bytesReadFromSocket)
            } else { socketFDBytesAvailable = 0 }

            if readIntoPreBuffer {
                sslPreBuffer.didWrite(bytesReadFromSocket)

                let bytesToCopy = min(totalBytesLeftToBeRead, bytesReadFromSocket)

                memcpy(buffer + totalBytesRead, UnsafeRawPointer(sslPreBuffer.readPointer), bytesToCopy)

                sslPreBuffer.didRead(bytesToCopy)

                totalBytesRead += bytesToCopy
                totalBytesLeftToBeRead -= bytesToCopy
            } else {
                totalBytesRead += bytesReadFromSocket
                totalBytesLeftToBeRead -= bytesReadFromSocket
            }

            done = totalBytesLeftToBeRead == 0
        }

        return socketError
    }

}
