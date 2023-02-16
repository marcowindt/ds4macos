//
//  SwiftAsyncUDPSocket+Send.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2019/1/18.
//  Copyright © 2019 chouheiwa. All rights reserved.
//

import Foundation
// MARK: - Send
extension SwiftAsyncUDPSocket {
    /// Asynchronously sends the given data, with the given timeout and tag.
    ///
    /// This method may only be used with a connected socket.
    /// Recall that connecting is optional for a UDP socket.
    /// For connected sockets, data can only be sent to the connected address.
    /// For non-connected sockets, the remote destination is specified for each packet.
    /// For more information about optionally connecting udp sockets, see the documentation for the connect methods.
    ///
    /// - Parameters:
    ///   - data:
    ///         The data to send.
    ///         If data is nil or zero-length, this method does nothing.
    ///   - timeout:
    ///         The timeout for the send opeartion.
    ///         If the timeout value is negative, the send operation will not use a timeout.
    ///         The default time out is nagative
    ///   - tag:
    ///         The tag is for your convenience.
    ///         It is not sent or received over the socket in any manner what-so-ever.
    ///         It is reported back as a parameter in the udpSocket:didSendDataWithTag:
    ///         or udpSocket:didNotSendDataWithTag:dueToError: methods.
    ///         You can use it as an array index, state id, type constant, etc.
    public func send(data: Data,
                     timeout: TimeInterval = -1,
                     tag: Int) {
        guard data.count > 0 else {
            return
        }

        let packet = SwiftAsyncUDPSendPacket(buffer: data, timeout: timeout, tag: tag)

        socketQueueDo(async: true, {
            self.sendQueue.append(packet)
            self.maybeDequeueSend()
        })
    }
    /// Asynchronously sends the given data, with the given timeout and tag.
    ///
    /// This method may only be used with a connected socket.
    /// Recall that connecting is optional for a UDP socket.
    /// For connected sockets, data can only be sent to the connected address.
    /// For non-connected sockets, the remote destination is specified for each packet.
    /// For more information about optionally connecting udp sockets, see the documentation for the connect methods.
    ///
    /// - Parameters:
    ///   - data:
    ///         The data to send.
    ///         If data is nil or zero-length, this method does nothing.
    ///   - toHost:
    ///         The destination to send the udp packet to.
    ///         May be specified as a domain name (e.g. "deusty.com") or an IP address string (e.g. "192.168.0.2").
    ///         You may also use the convenience strings of "loopback" or "localhost".
    ///   - port:
    ///         The port of the host to send to.
    ///   - timeout:
    ///         The timeout for the send opeartion.
    ///         If the timeout value is negative, the send operation will not use a timeout.
    ///         The default time out is nagative
    ///   - tag:
    ///         The tag is for your convenience.
    ///         It is not sent or received over the socket in any manner what-so-ever.
    ///         It is reported back as a parameter in the udpSocket:didSendDataWithTag:
    ///         or udpSocket:didNotSendDataWithTag:dueToError: methods.
    ///         You can use it as an array index, state id, type constant, etc.
    public func send(data: Data,
                     toHost: String,
                     port: UInt16,
                     timeout: TimeInterval = -1,
                     tag: Int) {
        guard data.count > 0 else {
            return
        }

        let packet = SwiftAsyncUDPSendPacket(buffer: data, timeout: timeout, tag: tag)

        packet.resolveInProgress = true

        asyncResolved(host: toHost, port: port) {
            packet.resolveInProgress = false

            packet.resolvedAddresses = $0
            packet.resolvedError = $1

            if packet == self.currentSend {
                self.doPreSend()
            }
        }

        socketQueueDo(async: true, {
            self.sendQueue.append(packet)
            self.maybeDequeueSend()
        })
    }
    /// Asynchronously sends the given data, with the given timeout and tag.
    ///
    /// This method may only be used with a connected socket.
    /// Recall that connecting is optional for a UDP socket.
    /// For connected sockets, data can only be sent to the connected address.
    /// For non-connected sockets, the remote destination is specified for each packet.
    /// For more information about optionally connecting udp sockets, see the documentation for the connect methods.
    ///
    /// - Parameters:
    ///   - data:
    ///         The data to send.
    ///         If data is nil or zero-length, this method does nothing.
    ///   - address:
    ///         The address to send the data to (specified as a sockaddr structure wrapped in a Data object).
    ///   - timeout:
    ///         The timeout for the send opeartion.
    ///         If the timeout value is negative, the send operation will not use a timeout.
    ///         The default time out is nagative
    ///   - tag:
    ///         The tag is for your convenience.
    ///         It is not sent or received over the socket in any manner what-so-ever.
    ///         It is reported back as a parameter in the udpSocket:didSendDataWithTag:
    ///         or udpSocket:didNotSendDataWithTag:dueToError: methods.
    ///         You can use it as an array index, state id, type constant, etc.
    public func send(data: Data,
                     address: Data,
                     timeout: TimeInterval = -1,
                     tag: Int) throws {
        guard data.count > 0 else {
            return
        }

        let packet = SwiftAsyncUDPSendPacket(buffer: data, timeout: timeout, tag: tag)

        packet.resolvedAddresses = try SocketDataType(data: address)

        socketQueueDo(async: true, {
            self.sendQueue.append(packet)
            self.maybeDequeueSend()
        })
    }

    /// See the documention in the Fliter file
    ///
    /// - Parameter filter: optional filter
    public func setSendFilter(_ filter: SwiftAsyncUDPSocketSendFilter?) {
        socketQueueDo(async: true, {
            self.sendFilter = filter
        })
    }
}
