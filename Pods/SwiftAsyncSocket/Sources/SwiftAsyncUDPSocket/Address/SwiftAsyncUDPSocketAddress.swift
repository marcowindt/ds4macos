//
//  SwiftAsyncUDPSocketAddress.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2019/1/11.
//  Copyright © 2019 chouheiwa. All rights reserved.
//

import Foundation

public struct SwiftAsyncUDPSocketAddress {
    public enum Types {
        case socket4
        case socket6

        init(isSock4: Bool) {
            self = isSock4 ? .socket4 : .socket6
        }
    }

    public let type: Types

    public let address: Data

    public let host: String

    public let port: UInt16

    init?(type: Types, socketFD: Int32) {
        self.type = type
        var sock: SocketAddrProtocol

        switch type {
        case .socket4:
            guard let socket = sockaddr_in.getLocalSocketFD(socketFD) else {
                return nil
            }
            sock = socket
        case .socket6:
            guard let socket = sockaddr_in6.getLocalSocketFD(socketFD) else {
                return nil
            }
            sock = socket
        }

        self.address = sock.data

        self.host = sock.host

        self.port = sock.port
    }

    init(type: Types, address: Data) {
        self.type = type
        self.address = address

        var sock: SocketAddrProtocol

        switch type {
        case .socket4:
            let socket: sockaddr_in = address.convert().pointee
            sock = socket
        case .socket6:
            let socket: sockaddr_in6 = address.convert().pointee
            sock = socket
        }

        self.host = sock.host
        self.port = sock.port
    }

    init(socket4: sockaddr_in) {
        self.type = .socket4
        self.address = socket4.data

        self.host = socket4.host
        self.port = socket4.port
    }

    init(socket6: sockaddr_in6) {
        self.type = .socket6
        self.address = socket6.data

        self.host = socket6.host
        self.port = socket6.port
    }

    static func == (left: SwiftAsyncUDPSocketAddress, right: SwiftAsyncUDPSocketAddress?) -> Bool {
        guard let right = right else { return false }

        guard left.type == right.type &&
            left.address.count == right.address.count else {
            return false
        }

        var leftAddr: SocketAddrProtocol
        var rightAddr: SocketAddrProtocol

        switch left.type {
        case .socket4:
            let sockL: sockaddr_in = left.address.convert().pointee
            let sockR: sockaddr_in = right.address.convert().pointee
            leftAddr = sockL
            rightAddr = sockR
        case .socket6:
            let sockL: sockaddr_in6 = left.address.convert().pointee
            let sockR: sockaddr_in6 = right.address.convert().pointee
            leftAddr = sockL
            rightAddr = sockR
        }

        return leftAddr.host == rightAddr.host && leftAddr.port == rightAddr.port
    }
}
