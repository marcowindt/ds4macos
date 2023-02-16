//
//  SwiftAsyncUDPSocketDelegate.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2019/1/10.
//  Copyright © 2019 chouheiwa. All rights reserved.
//

import Foundation

public protocol SwiftAsyncUDPSocketDelegate: AnyObject {
    /// By design, UDP protocol doesn't need to connect
    /// So that means, if this method was called,
    /// it can't prove that the server can receive data.
    /// It can only prove that you can send data.
    ///
    /// If you call connect() function and socket create successful,
    /// this method will be called
    ///
    /// - Parameters:
    ///   - socket: socket
    ///   - address: connect address
    func updSocket(_ socket: SwiftAsyncUDPSocket, didConnectTo address: SwiftAsyncUDPSocketAddress)
    /// This method was called may be sereval problem
    /// such as host can only support ipv4 and you set isIPv4Enable to false
    ///
    /// If you call connect() function and socket create failtrue,
    /// this method will be called
    ///
    /// - Parameters:
    ///   - socket: socket
    ///   - error: error
    func updSocket(_ socket: SwiftAsyncUDPSocket, didNotConnect error: SwiftAsyncSocketError)
    /// Called when data with given tag has been sent
    /// Can't prove that server receive data
    ///
    /// - Parameters:
    ///   - socket: socket
    ///   - tag: tag
    func updSocket(_ socket: SwiftAsyncUDPSocket, didSendDataWith tag: Int)
    /// Called if an error occurs to send a data
    /// Error could be due to timeout,
    /// or something more serious such as
    /// the data being too large to fit in a sigle packet.
    ///
    /// - Parameters:
    ///   - socket: socket
    ///   - tag: tag
    ///   - error: error reason
    func updSocket(_ socket: SwiftAsyncUDPSocket,
                   didNotSendDataWith tag: Int,
                   dueTo error: SwiftAsyncSocketError)
    /// This method will be called when the socket has received data
    ///
    /// - Parameters:
    ///   - socket: socket
    ///   - data: data
    ///   - address: where to send
    ///   - filterContext: the given filter context
    func updSocket(_ socket: SwiftAsyncUDPSocket,
                   didReceive data: Data,
                   from address: SwiftAsyncUDPSocketAddress,
                   withFilterContext filterContext: Any?)
    /// Called when the socket is closed
    ///
    /// - Parameters:
    ///   - socket: socket
    ///   - error: error reason
    func updSocket(_ socket: SwiftAsyncUDPSocket, didCloseWith error: SwiftAsyncSocketError?)
}

public extension SwiftAsyncUDPSocketDelegate {
    func updSocket(_ socket: SwiftAsyncUDPSocket, didConnectTo address: SwiftAsyncUDPSocketAddress) {}

    func updSocket(_ socket: SwiftAsyncUDPSocket, didNotConnect error: SwiftAsyncSocketError) {}

    func updSocket(_ socket: SwiftAsyncUDPSocket, didSendDataWith tag: Int) {}

    func updSocket(_ socket: SwiftAsyncUDPSocket,
                          didNotSendDataWith tag: Int,
                          dueTo error: SwiftAsyncSocketError) {}

    func updSocket(_ socket: SwiftAsyncUDPSocket,
                          didReceive data: Data,
                          from address: SwiftAsyncUDPSocketAddress,
                          withFilterContext filterContext: Any?) {}

    func updSocket(_ socket: SwiftAsyncUDPSocket, didCloseWith error: SwiftAsyncSocketError?) {}
}
