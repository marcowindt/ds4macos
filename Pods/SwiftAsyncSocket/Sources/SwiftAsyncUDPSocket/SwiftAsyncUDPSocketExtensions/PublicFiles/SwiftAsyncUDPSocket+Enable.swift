//
//  SwiftAsyncUDPSocket+Enable.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2019/1/18.
//  Copyright © 2019 chouheiwa. All rights reserved.
//

import Foundation

// MARK: - Enable
extension SwiftAsyncUDPSocket {

    /// By default, only one socket can be bound to a given IP address + port at a time.
    /// To enable multiple processes to simultaneously bind to the same address+port,
    /// you need to enable this functionality in the socket.  All processes that wish to
    /// use the address+port simultaneously must all enable reuse port on the socket
    /// bound to that port.
    ///
    /// - Parameter isEnable: enable
    /// - Throws: error
    public func enableReusePort(isEnable: Bool) throws {
        try socketQueueDoWithError {
            try preOpen()

            if !flags.contains(.didCreatSockets) {
                try createSocket(IPv4: isIPv4Enable, IPv6: isIPv6Enable)
            }

            var value = isEnable ? 1 : 0

            let setSockopt: (Int32) throws -> Void = {
                let status = Darwin.setsockopt($0, SOL_SOCKET, SO_REUSEPORT,
                                               &value,
                                               socklen_t(MemoryLayout.size(ofValue: value)))

                guard status == 0 else {
                    throw SwiftAsyncSocketError.errno(code: errno,
                                                      reason: "Error in setsockopt() function")
                }
            }

            if socket4FD != -1 {
                try setSockopt(socket4FD)
            }

            if socket6FD != -1 {
                try setSockopt(socket6FD)
            }
        }
    }
    /// By default, the underlying socket in the OS will not allow you to send broadcast messages.
    /// In order to send broadcast messages, you need to enable this functionality in the socket.
    ///
    /// A broadcast is a UDP message to addresses like "192.168.255.255" or "255.255.255.255" that is
    /// delivered to every host on the network.
    /// The reason this is generally disabled by default (by the OS) is to prevent
    /// accidental broadcast messages from flooding the network.
    ///
    /// - Parameter isEnable: enable
    /// - Throws: error
    public func enableBroadcast(isEnable: Bool) throws {
        try socketQueueDoWithError {
            try preOpen()

            if !flags.contains(.didCreatSockets) {
                try createSocket(IPv4: isIPv4Enable, IPv6: isIPv6Enable)
            }
            var value = isEnable ? 1 : 0
            let setSockopt: (Int32) throws -> Void = {
                let status = Darwin.setsockopt($0, SOL_SOCKET, SO_BROADCAST,
                                               &value,
                                               socklen_t(MemoryLayout.size(ofValue: value)))

                guard status == 0 else {
                    throw SwiftAsyncSocketError.errno(code: errno,
                                                      reason: "Error in setsockopt() function")
                }
            }

            if socket4FD != -1 {
                try setSockopt(socket4FD)
            }

            // IPv6 does not implement broadcast,
            // the ability to send a packet to all hosts on the attached link.
            // The same effect can be achieved by sending
            // a packet to the link-local all hosts multicast group.
        }
    }
}
