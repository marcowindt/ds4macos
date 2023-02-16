//
//  SocketDataType.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2019/1/14.
//  Copyright © 2019 chouheiwa. All rights reserved.
//

import Foundation

public enum SocketDataType {
    case IPv4Data(_ data: Data)
    case IPv6Data(_ data: Data)
    case bothData(IPv4: Data, IPv6: Data)

    init(IPv4 ipv4Data: Data?, IPv6 ipv6Data: Data?) throws {
        if let ipv4Data = ipv4Data, let ipv6Data = ipv6Data {
            self = .bothData(IPv4: ipv4Data, IPv6: ipv6Data)
        } else if let ipv4Data = ipv4Data {
            self = .IPv4Data(ipv4Data)
        } else if let ipv6Data = ipv6Data {
            self = .IPv6Data(ipv6Data)
        } else {
            throw SwiftAsyncSocketError.badParamError("Both ipv4 & ipv6 data was nil")
        }
    }

    mutating func change(IPv4Enable: Bool, IPv6Enable: Bool) throws {
        guard IPv4Enable || IPv6Enable else {
            throw SwiftAsyncSocketError.badParamError(
                "Both IPv4 and IPv4 are disable")
        }
        // If both IPv6Enable enable and IPv4Enable then we don't need to do anything
        guard !(IPv6Enable && IPv4Enable) else {
            return
        }

        switch self {
        case .bothData(let IPv4Data, let IPv6Data):
            guard IPv4Enable else {
                self = .IPv6Data(IPv6Data)
                return
            }

            self = .IPv4Data(IPv4Data)
        case .IPv4Data:
            guard IPv4Enable else {
                throw SwiftAsyncSocketError.badParamError(
                    "IPv4 has been disabled and specified interface doesn't support IPv6.")
            }
        case .IPv6Data:
            guard IPv6Enable else {
                throw SwiftAsyncSocketError.badParamError(
                    "IPv6 has been disabled and specified interface doesn't support IPv4.")
            }
        }
    }
}

public extension SocketDataType {
    init(data: Data) throws {
        var address4: Data?
        var address6: Data?

        if data.count >= MemoryLayout<sockaddr>.size {
            let sockaddrs: UnsafePointer<sockaddr> = data.convert()

            if sockaddrs.pointee.sa_family == AF_INET &&
                data.count == MemoryLayout<sockaddr_in>.size {
                address4 = data
            } else if sockaddrs.pointee.sa_family == AF_INET6 &&
                data.count == MemoryLayout<sockaddr_in6>.size {
                address6 = data
            }
        }

        try self.init(IPv4: address4, IPv6: address6)
    }

    static func lookup(host: String, port: UInt16,
                              hasNumeric: Bool = false,
                              isTCP: Bool = true) throws -> SocketDataType {
        guard host != "localhost" && host != "loopback" else {
            let (nativeAddr4, nativeAddr6) = sockaddr.getSockData(fromLocalHost: port)

            return try SocketDataType(IPv4: nativeAddr4, IPv6: nativeAddr6)
        }

        var hints = addrinfo()

        hints.ai_family = PF_UNSPEC
        hints.ai_socktype = isTCP ? SOCK_STREAM : SOCK_DGRAM
        hints.ai_protocol = isTCP ? IPPROTO_TCP : IPPROTO_UDP

        if hasNumeric {
            hints.ai_flags = AI_NUMERICHOST
        }

        var res: UnsafeMutablePointer<addrinfo>?

        let error = getaddrinfo(host, String(port), &hints, &res)

        guard error == 0 else {
            throw SwiftAsyncSocketError.gaiError(code: error)
        }
        defer {
            freeaddrinfo(res)
        }

        var address4: Data?
        var address6: Data?

        while res != nil {
            guard let pointer = res else {
                fatalError("Code can not be here")
            }

            let type = pointer.pointee.ai_family

            let sock: UnsafeMutablePointer<sockaddr> = pointer.pointee.ai_addr

            if type == AF_INET {
                address4 = Data(bytes: sock, count: Int(pointer.pointee.ai_addrlen))
            } else if type == AF_INET6 {
                let sock6 = sock.withMemoryRebound(to: sockaddr_in6.self,
                                                   capacity: 1, {$0})

                if sock6.pointee.sin6_port == 0 {
                    sock6.pointee.sin6_port = CFSwapInt16HostToBig(port)
                }

                address6 = sock6.pointee.data
            }

            res = res?.pointee.ai_next
        }

        guard address4 != nil || address6 != nil else {
            throw SwiftAsyncSocketError.gaiError(code: EAI_FAIL)
        }

        return try SocketDataType(IPv4: address4, IPv6: address6)
    }

    static func getInterfaceAddress(interface description: String, port: UInt16?) -> SocketDataType? {
        let componments = description.split(separator: ":")

        var interface: String?

        if componments.count > 0 {
            if let temp = componments.first {
                interface = String(temp)
            }
        }

        var portTotal = port ?? 0

        if componments.count > 1 && portTotal == 0 {
            guard let componmentData = String(componments[1]).data(using: .utf8) else {
                assert(false, "Invid logic")
                fatalError("Invid logic")
            }

            let portL = strtol(componmentData.convert(), nil, 10)

            if portL > 0 && portL <= UINT16_MAX {
                portTotal = UInt16(portL)
            }
        }

        if interface == nil {
            let (sock4, sock6) = sockaddr.getSockData(fromAny: portTotal)

            return try? SocketDataType(IPv4: sock4, IPv6: sock6)
        } else if let interface = interface, (interface == "localhost" || interface == "loopback") {
            let (sock4, sock6) = sockaddr.getSockData(fromLocalHost: portTotal)

            return try? SocketDataType(IPv4: sock4, IPv6: sock6)
        } else {
            return getDataFrom(other: interface, port: portTotal)
        }
    }

    private static func getDataFrom(other interface: String?, port: UInt16) -> SocketDataType? {
        let iface: UnsafePointer<Int8>? = interface?.data(using: .utf8)?.convert()

        var addrs: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&addrs) == 0 else {
            return nil
        }
        guard let firstAddr = addrs else {
            return nil
        }

        var addr4: Data?
        var addr6: Data?

        for pointer in sequence(first: firstAddr, next: {$0.pointee.ifa_next}) {
            getAddr(from: pointer.pointee, addr4: &addr4, addr6: &addr6, iface: iface, port: port)
        }
        freeifaddrs(addrs)
        return try? SocketDataType(IPv4: addr4, IPv6: addr6)
    }

    private static func getAddr(from cursor: ifaddrs,
                                addr4: inout Data?,
                                addr6: inout Data?,
                                iface: UnsafePointer<Int8>?,
                                port: UInt16) {
        let saFamily = cursor.ifa_addr.pointee.sa_family

        if addr4 == nil && saFamily == AF_INET {
            var nativeAddr4 = cursor.ifa_addr.pointee.copyToSockaddr_in()

            if strcmp(cursor.ifa_name, iface) == 0 {
                // Name match
                nativeAddr4.sin_port = CFSwapInt16HostToBig(port)

                addr4 = nativeAddr4.data
            } else {
                let ipAddr: UnsafeMutablePointer<Int8> = malloc(Int(INET_ADDRSTRLEN))!
                    .assumingMemoryBound(to: Int8.self)

                defer {
                    free(ipAddr)
                }

                let conversion = inet_ntop(AF_INET,
                                           &(nativeAddr4.sin_addr),
                                           ipAddr,
                                           socklen_t(INET_ADDRSTRLEN))

                if conversion != nil && strcmp(ipAddr, iface) == 0 {
                    nativeAddr4.sin_port = CFSwapInt16HostToBig(port)
                    // ip matched
                    addr4 = nativeAddr4.data
                }
            }
        } else if addr6 == nil && saFamily == AF_INET6 {
            var nativeAddr6 = cursor.ifa_addr.withMemoryRebound(to: sockaddr_in6.self, capacity: 1, {$0.pointee})

            if strcmp(cursor.ifa_name, iface) == 0 {
                // Name match

                nativeAddr6.sin6_port = CFSwapInt16HostToBig(port)

                addr6 = Data(bytes: &nativeAddr6, count: MemoryLayout.size(ofValue: nativeAddr6))
            } else {
                let ipAddr: UnsafeMutablePointer<Int8> = malloc(Int(INET6_ADDRSTRLEN))!
                    .assumingMemoryBound(to: Int8.self)

                defer {
                    free(ipAddr)
                }

                let conversion = inet_ntop(AF_INET,
                                           &(nativeAddr6.sin6_addr),
                                           ipAddr,
                                           socklen_t(INET6_ADDRSTRLEN))

                // find ip
                if conversion != nil && strcmp(ipAddr, iface) == 0 {
                    nativeAddr6.sin6_port = CFSwapInt16HostToBig(port)
                    addr6 = nativeAddr6.data
                }
            }
        }
    }
}
