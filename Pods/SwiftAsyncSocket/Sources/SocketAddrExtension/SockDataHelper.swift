//
//  SockDataHelper.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2018/12/20.
//  Copyright © 2018 chouheiwa. All rights reserved.
//

import Foundation

struct SockDataHelper {
    let data: Data
}

extension SockDataHelper {
    var port: UInt16 {
        var port: UInt16 = 0
        var host: String = ""
        var family: sa_family_t = sa_family_t()
        get(host: &host, port: &port, family: &family)

        return port
    }

    private func get(host hosts: inout String, port: inout UInt16, family: inout sa_family_t) {
        guard data.count >= MemoryLayout<sockaddr>.size else {
            return
        }

        let sockAddr: sockaddr = data.convert().pointee

        if sockAddr.sa_family == AF_INET {
            let sock: sockaddr_in = data.convert().pointee

            hosts = sock.host
            port = sock.port
            family = sockAddr.sa_family
        } else if sockAddr.sa_family == AF_INET6 {
            let sock: sockaddr_in6 = data.convert().pointee

            hosts = sock.host
            port = sock.port
            family = sockAddr.sa_family
        }
    }

    private func host(fromSockAddr4 sockAddr4: inout sockaddr_in) -> String {
        let length = Int(INET_ADDRSTRLEN)

        guard let addrBuf = malloc(length)?.assumingMemoryBound(to: Int8.self) else { fatalError() }
        memset(addrBuf, 0, length)

        defer {
            free(addrBuf)
        }

        if inet_ntop(AF_INET, &(sockAddr4.sin_addr), addrBuf, socklen_t(length)) == nil {
            addrBuf.pointee = 0
        }

        return String(cString: addrBuf, encoding: .ascii) ?? ""
    }

    private func host(fromSockAddr6 sockAddr6: inout sockaddr_in6) -> String {
        let length = Int(INET_ADDRSTRLEN)

        guard let addrBuf = malloc(length)?.assumingMemoryBound(to: Int8.self) else { fatalError() }
        memset(addrBuf, 0, length)

        defer {
            free(addrBuf)
        }

        if inet_ntop(AF_INET6, &(sockAddr6.sin6_addr), addrBuf, socklen_t(length)) == nil {
            addrBuf.pointee = 0
        }

        return String(cString: addrBuf, encoding: .ascii) ?? ""
    }
}
