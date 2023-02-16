//
//  SwiftAsyncUDPSocket+Multicast.swift
//  SwiftAsyncSocket iOS
//
//  Created by chouheiwa on 2019/1/17.
//  Copyright © 2019 chouheiwa. All rights reserved.
//

import Foundation

fileprivate extension SocketDataType {
    enum GroupData {
        case IPv4(group: Data, interface: Data)
        case IPv6(group: Data, interface: Data)
    }

    static func & (left: SocketDataType, right: SocketDataType) throws -> GroupData {
        switch left {
        case .IPv4Data(let group):
            switch right {
            case .IPv4Data(let interface),
                 .bothData(let interface, _):
                return GroupData.IPv4(group: group, interface: interface)
            default:
                throw SwiftAsyncSocketError.badParamError("Socket, group, and interface do not " +
                    "have matching IP versions")
            }
        case .IPv6Data(let group):
            switch right {
            case .IPv6Data(let interface),
                 .bothData(_, let interface):
                return GroupData.IPv6(group: group, interface: interface)
            default:
                throw SwiftAsyncSocketError.badParamError("Socket, group, and interface do not " +
                    "have matching IP versions")
            }
        case .bothData(let groupIpv4, let groupIpv6):
            switch right {
            case .IPv4Data(let interface),
                 .bothData(let interface, _):
                return GroupData.IPv4(group: groupIpv4, interface: interface)
            case .IPv6Data(let interface):
                return GroupData.IPv6(group: groupIpv6, interface: interface)
            }
        }
    }
}
// MARK: - Multicast
extension SwiftAsyncUDPSocket {
    func preJoin() throws {
        try preOpen()

        guard flags.contains(.didBind) else {
            throw SwiftAsyncSocketError.badConfig(msg:
                "Must bind a socket before joining a multicast group.")
        }

        guard !flags.contains(.connecting) && flags.contains(.didConnect) else {
            throw SwiftAsyncSocketError.badConfig(msg:
                "Cannot join a multicast group if connected.")
        }
    }

    enum MulticastType {
        case join, leave

        var rawValue: Int32 {
            switch self {
            case .join:
                return IP_ADD_MEMBERSHIP
            case .leave:
                return IP_DROP_MEMBERSHIP
            }
        }
    }

    func performWithQueue(requestType: MulticastType,
                          group: String,
                          interface: String?) throws {
        var err: SwiftAsyncSocketError?
        socketQueueDo {
            do {
                try self.perform(requestType: requestType, group: group, interface: interface)
            } catch let error as SwiftAsyncSocketError {
                err = error
            } catch {
                fatalError("\(error)")
            }
        }

        if let error = err {
            throw error
        }
    }

    private func perform(requestType: MulticastType,
                         group: String,
                         interface: String?) throws {
        try preJoin()

        let groupAddr = try SocketDataType.lookup(host: group, port: 0,
                                                  hasNumeric: true, isTCP: false)

        guard let interfaceAddr = SocketDataType.getInterfaceAddress(interface: interface ?? "",
                                                                     port: 0) else {
            throw SwiftAsyncSocketError.badParamError("Unknown interface. Specify valid interface " +
                "by name (e.g. \"en1\") or IP address.")
        }

        let finalType = try groupAddr & interfaceAddr

        switch finalType {
        case .IPv4(let group, let interface):
            var imreq = Darwin.ip_mreq()
            let nativeGroup: sockaddr_in = group.convert().pointee
            let nativeInterface: sockaddr_in = interface.convert().pointee

            imreq.imr_multiaddr = nativeGroup.sin_addr
            imreq.imr_interface = nativeInterface.sin_addr

            let result = Darwin.setsockopt(socket4FD, IPPROTO_IP, requestType.rawValue,
                                           &imreq,
                                           socklen_t(MemoryLayout.size(ofValue: imreq)))

            guard result == 0 else {
                throw SwiftAsyncSocketError.errno(code: noErr,
                                                  reason: "Error in setsockopt() function")
            }

            closeSocket6()
        case .IPv6(let group, let interface):
            var imreq = Darwin.ipv6_mreq()
            let nativeGroup: sockaddr_in6 = group.convert().pointee
            let nativeInterface: sockaddr_in6 = interface.convert().pointee

            imreq.ipv6mr_multiaddr = nativeGroup.sin6_addr
            imreq.ipv6mr_interface = nativeInterface.index

            let result = Darwin.setsockopt(socket6FD, IPPROTO_IPV6, requestType.rawValue,
                                           &imreq,
                                           socklen_t(MemoryLayout.size(ofValue: imreq)))

            guard result == 0 else {
                throw SwiftAsyncSocketError.errno(code: noErr,
                                                  reason: "Error in setsockopt() function")
            }

            closeSocket4()

        }
    }
}
