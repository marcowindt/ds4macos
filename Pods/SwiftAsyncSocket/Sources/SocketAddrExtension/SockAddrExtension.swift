//
//  SockAddrExtension.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2018/12/20.
//  Copyright © 2018 chouheiwa. All rights reserved.
//

import Foundation

extension sockaddr {
    mutating func copyToSockaddr_in() -> sockaddr_in {
        let length = 16

        return withUnsafePointer(to: &self) {
            return Data(bytes: $0, count: length).withUnsafeBytes { buffer in
                return buffer.bindMemory(to: sockaddr_in.self).baseAddress!.pointee
            }
        }
    }

    static func getSock(fromLocalHost port: UInt16) -> (sockaddr_in, sockaddr_in6) {
        return self.getSock(isLoopback: true, port: port)
    }

    static func getSock(fromAny port: UInt16) -> (sockaddr_in, sockaddr_in6) {
        return self.getSock(isLoopback: false, port: port)
    }

    static func getSockData(fromLocalHost port: UInt16) -> (Data, Data) {
        let (sockaddr4, sockaddr6) = sockaddr.getSock(fromLocalHost: port)

        return (sockaddr4.data, sockaddr6.data)
    }

    static func getSockData(fromAny port: UInt16) -> (Data, Data) {
        let (sockaddr4, sockaddr6) = sockaddr.getSock(fromAny: port)

        return (sockaddr4.data, sockaddr6.data)
    }

    private static func getSock(isLoopback: Bool,
                                port: UInt16) -> (sockaddr_in, sockaddr_in6) {
        var sockaddr4 = sockaddr_in()

        sockaddr4.sin_len = __uint8_t(MemoryLayout.size(ofValue: sockaddr4))
        sockaddr4.sin_family = sa_family_t(AF_INET)
        sockaddr4.sin_port = CFSwapInt16HostToBig(port)
        sockaddr4.sin_addr.s_addr = CFSwapInt32HostToBig(isLoopback ? INADDR_LOOPBACK : INADDR_ANY)

        var sockaddr6 = sockaddr_in6()

        sockaddr6.sin6_len = __uint8_t(MemoryLayout.size(ofValue: sockaddr6))
        sockaddr6.sin6_family = sa_family_t(AF_INET6)
        sockaddr6.sin6_port = CFSwapInt16HostToBig(port)
        sockaddr6.sin6_addr = isLoopback ? in6addr_loopback : in6addr_any

        return (sockaddr4, sockaddr6)
    }
}
