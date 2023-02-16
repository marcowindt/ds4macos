//
//  SwiftAsyncUDPSocket+Connect.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2019/1/18.
//  Copyright © 2019 chouheiwa. All rights reserved.
//

import Foundation
// MARK: - Connect
extension SwiftAsyncUDPSocket {

    /// Connects the UDP socket to the given host and port.
    /// By design, UDP is a connectionless protocol, and connecting is not needed.
    ///
    /// Choosing to connect to a specific host/port has the following effect:
    /// - You will only be able to send data to the connected host/port.
    /// - You will only be able to receive data from the connected host/port.
    /// - You will receive ICMP messages that come from the connected host/port, such as "connection refused".
    ///
    /// The actual process of connecting a UDP socket does not result in any communication on the socket.
    /// It simply changes the internal state of the socket.
    ///
    /// You cannot bind a socket after it has been connected.
    /// You can only connect a socket once.
    ///
    /// This method is asynchronous as it requires a DNS lookup to resolve the given host name.
    /// If an obvious error is detected, this method immediately returns NO and sets errPtr.
    /// If you don't care about the error, you can pass nil for errPtr.
    /// Otherwise, this method returns YES and begins the asynchronous connection process.
    /// The result of the asynchronous connection process will be reported via the delegate methods.
    ///
    /// - Parameters:
    ///   - host: a domain name (e.g. "deusty.com") or an IP address string (e.g. "192.168.0.2").
    ///   - port: port
    /// - Throws: failture
    public func connect(to host: String, port: UInt16) throws {
        try socketQueueDoWithError {
            try self.connectPreJob(prepareBlock: { (packet) in
                packet.resolveInProgress = true

                self.asyncResolved(host: host, port: port, completionBlock: {
                    packet.resolveInProgress = false
                    packet.resolvedAddresses = $0
                    packet.resolvedError = $1

                    self.maybeConnect()
                })
            })
        }
    }

    public func connect(to address: Data) throws {
        try socketQueueDoWithError {
            try self.connectPreJob(prepareBlock: { (packet) in
                packet.resolvedAddresses = try? SocketDataType(data: address)
            })
        }
    }

}
