//
//  SwiftAsyncSocketDelegate.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2018/12/10.
//  Copyright © 2018 chouheiwa. All rights reserved.
//

import Foundation

/// SwiftAsyncSocketDelegate
/// All the method will be called when
/// the following two conditions are satisfied:
/// 1. already set delegate
/// 2. already set delegateQueue
public protocol SwiftAsyncSocketDelegate: AnyObject {

    /// This method will be called before socket(_ socket: SwiftAsyncSocket, didAccept newSocket: SwiftAsyncSocket)
    /// If method return is not nil, then socket action will be done at the return queue.
    ///
    /// - Parameters:
    ///   - address: Connect Socket data. You can convert the data to the 
    ///   - socket: socket
    /// - Returns: New Socket action queue
    func newSocketQueueForConnection(from address: Data, on socket: SwiftAsyncSocket) -> DispatchQueue?
    /// Here is the buffer that you can make it easy to use.
    /// The origin prebuffer is the normal buffer. It is only some contiguous memory space.
    /// You can make a ring buffer to instead of my buffer.
    /// Just implement the SwiftAsyncSocketbuffer
    /// If you don't want to create buffer by yourself, just return nil or don't implement this method
    ///
    /// - Parameter socket: socket
    func socketNeedBuffer(_ socket: SwiftAsyncSocket) -> SwiftAsyncSocketBuffer?

    /// This method will be called when you called SwiftAsyncSocket.accept() as sercer and
    /// socket client connected to this server
    /// If you want to make the socket alive, you need to control the life circle of the newSocket,
    /// sucn as make it to delegate's property
    ///
    /// - Parameters:
    ///   - socket: accepted socket
    ///   - newSocket: new connected socket
    func socket(_ socket: SwiftAsyncSocket, didAccept newSocket: SwiftAsyncSocket)

    /// This method will be called when you call SwiftAsyncSocket.connect(toHost:, onPort:),
    /// when this function has been called, it means your socket has been already success.
    /// Then you can call socket.read to readData from server or socket.write to send data
    /// - Parameters:
    ///   - socket: socket
    ///   - toHost: Connected host
    ///   - port: Connected service port
    func socket(_ socket: SwiftAsyncSocket, didConnect toHost: String, port: UInt16)

    /// This method will be called when you call SwiftAsyncSocket.connect(toURL:),
    /// when this function has been called, it means your socket has been already success.
    /// Then you can call socket.read to readData from server or socket.write to send data
    ///
    /// - Parameters:
    ///   - socket: socket
    ///   - toURL: Connected URL
    func socket(_ socket: SwiftAsyncSocket, didConnect toURL: URL)

    /// When you call readData's method, if the socket transmit data reach the requirement,
    /// such as you want to read a given length, when the socket transmit the given length,
    /// then this method will be called.
    ///
    /// - Parameters:
    ///   - socket: socket
    ///   - data: socket read data
    ///   - tag: call read function's tag
    func socket(_ socket: SwiftAsyncSocket, didRead data: Data, with tag: Int)

    /// This method will be called when you call readDataToData or readDataToLength
    /// If this method called, it means server send data.
    ///
    /// - Parameters:
    ///   - socket: socket
    ///   - length: this time server send data length
    ///   - tag: call read's function
    func socket(_ socket: SwiftAsyncSocket, didReadParticalDataOf length: UInt, with tag: Int)

    /// This method will be called when socket did write full data you want to send with write method
    ///
    /// - Parameters:
    ///   - socket: socket
    ///   - tag: the tag when you call write method
    func socket(_ socket: SwiftAsyncSocket, didWriteDataWith tag: Int)

    /// When socket can not send all the bytes in one time. This method will be called to tell you,
    /// how many bytes you send. You may use this method when you need to upload a file.
    ///
    /// - Parameters:
    ///   - socket: socket
    ///   - length: already send data length
    ///   - tag: the tag when you call write method
    func socket(_ socket: SwiftAsyncSocket, didWriteParticalDataOf length: UInt, with tag: Int)

    /// When this method called, it means that read method timeout.
    /// If you want to continue read, you can return a non zero time or a negative time to make no timeout
    ///
    /// - Parameters:
    ///   - socket: socket
    ///   - tag: read function tag
    ///   - elapsed: already use time
    ///   - bytesDone: already read bytes
    func socket(_ socket: SwiftAsyncSocket,
                shouldTimeoutReadWith tag: Int,
                elapsed: TimeInterval,
                bytesDone: UInt) -> TimeInterval?

    /// When this method called, it means that write method timeout.
    /// If you want to continue write, you can return a non zero time or a negative time to make no timeout
    ///
    /// - Parameters:
    ///   - socket: socket
    ///   - tag: write function tag
    ///   - elapsed: already use time
    ///   - bytesDone: already write bytes
    func socket(_ socket: SwiftAsyncSocket,
                shouldTimeoutWriteWith tag: Int,
                elapsed: TimeInterval,
                bytesDone: UInt) -> TimeInterval?

    /// When this method called, you can not read data any more. The read stream have already been closed.
    /// But you can still write
    /// - Parameter socket: socket
    func socketDidClosedReadStream(_ socket: SwiftAsyncSocket)

    /// This method will be called when socket has already disconnect.
    /// The error tells the close reason.
    ///
    /// - Parameters:
    ///   - socket: socket
    ///   - error: close reason. It can be nil
    func socket(_ socket: SwiftAsyncSocket?, didDisconnectWith error: SwiftAsyncSocketError?)

    /// Socket have already complete SSL handshake
    ///
    /// - Parameter socket: socket
    func socketDidSecure(_ socket: SwiftAsyncSocket)

    /// When this method called, it means ssl handshake continue,
    /// and you need to confirm that Cert can be accepted.
    /// If you have the result, then call completionHandler(),
    /// the socket will wait until call completionHandler(),
    /// If you want to continue connect, this function need you to return a true result
    /// - Parameters:
    ///   - socket: socket
    ///   - trust: trust SecTrust
    ///   - completionHandler: completionHandler
    /// - Returns: Can continue
    func socket(_ socket: SwiftAsyncSocket,
                didReceive trust: SecTrust,
                completionHandler: @escaping((Bool) -> Void)) -> Bool
}

// MARK: - Default Implement if you don't want to hook, if you want to hook, then implement these public functions
// We use extension to make it can be optional
//       - 为协议完成默认实现。如果你希望启用某些方法，可以对方法进行覆写
public extension SwiftAsyncSocketDelegate {
    func newSocketQueueForConnection(from address: Data,
                                            on socket: SwiftAsyncSocket) -> DispatchQueue? {return nil}

    func socketNeedBuffer(_ socket: SwiftAsyncSocket) -> SwiftAsyncSocketBuffer? {return nil}

    func socket(_ socket: SwiftAsyncSocket, didAccept newSocket: SwiftAsyncSocket) {}

    func socket(_ socket: SwiftAsyncSocket, didConnect toHost: String, port: UInt16) {}

    func socket(_ socket: SwiftAsyncSocket, didConnect toURL: URL) {}

    func socket(_ socket: SwiftAsyncSocket, didRead data: Data, with tag: Int) {}

    func socket(_ socket: SwiftAsyncSocket, didReadParticalDataOf length: UInt, with tag: Int) {}

    func socket(_ socket: SwiftAsyncSocket, didWriteDataWith tag: Int) {}

    func socket(_ socket: SwiftAsyncSocket, didWriteParticalDataOf length: UInt, with tag: Int) {}

    func socket(_ socket: SwiftAsyncSocket,
                       shouldTimeoutReadWith tag: Int,
                       elapsed: TimeInterval,
                       bytesDone: UInt) -> TimeInterval? { return nil }

    func socket(_ socket: SwiftAsyncSocket,
                       shouldTimeoutWriteWith tag: Int,
                       elapsed: TimeInterval,
                       bytesDone: UInt) -> TimeInterval? { return nil }

    func socketDidClosedReadStream(_ socket: SwiftAsyncSocket) {}

    func socket(_ socket: SwiftAsyncSocket?, didDisconnectWith error: SwiftAsyncSocketError?) {}

    func socketDidSecure(_ socket: SwiftAsyncSocket) {}

    func socket(_ socket: SwiftAsyncSocket,
                       didReceive trust: SecTrust,
                       completionHandler: @escaping ((Bool) -> Void)) -> Bool { return false }
}
