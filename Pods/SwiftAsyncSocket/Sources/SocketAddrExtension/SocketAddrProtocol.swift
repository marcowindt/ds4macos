//
//  SocketAddProtocol.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2018/12/16.
//  Copyright © 2018 chouheiwa. All rights reserved.
//

import Foundation

protocol SocketAddrProtocol {
    /// use getpeername function to get sock struct
    ///
    /// - Parameter socketFD: socketFD
    /// - Returns: sock struct
    static func getPeerSocketFD(_ socketFD: Int32) -> Self?
    /// use getsockname function to get sock struct
    ///
    /// - Parameter socketFD: socketFD
    /// - Returns: sock struct
    static func getLocalSocketFD(_ socketFD: Int32) -> Self?
    /// use accept function to get sock struct
    ///
    /// - Parameter socketFD: socketFD
    /// - Returns: sock struct
    static func getAcceptSocketFD(_ socketFD: Int32) -> (Self?, Int32)

    init()

    var host: String {get}

    var port: UInt16 {get}

    var data: Data {get}
}

extension SocketAddrProtocol {

    var data: Data {
        var `self` = self

        return Data(bytes: &self, count: MemoryLayout.size(ofValue: self))
    }

    static func getPeerSocketFD(_ socketFD: Int32) -> Self? {
        var sock = Self()

        var aSockaddrLen = socklen_t(MemoryLayout<Self>.size)
        guard let pointer = withUnsafeMutableBytes(of: &sock, {$0})
            .bindMemory(to: sockaddr.self)
            .baseAddress else { fatalError("Never apper here") }

        guard getpeername(socketFD, pointer, &aSockaddrLen) == 0 else {
            return nil
        }

        return sock
    }
    // getsockname
    static func getLocalSocketFD(_ socketFD: Int32) -> Self? {
        var sock = Self()

        var aSockaddrLen = socklen_t(MemoryLayout<Self>.size)

        guard let pointer = withUnsafeMutableBytes(of: &sock, {$0})
            .bindMemory(to: sockaddr.self)
            .baseAddress else { fatalError("Never apper here") }

        guard getsockname(socketFD, pointer, &aSockaddrLen) == 0 else {
            return nil
        }

        return sock
    }
    // accept
    static func getAcceptSocketFD(_ socketFD: Int32) -> (Self?, Int32) {
        var childSocketFD: Int32 = 0

        var sock = Self()

        var aSockaddrLen = socklen_t(MemoryLayout<Self>.size)

        guard let pointer = withUnsafeMutableBytes(of: &sock, {$0})
            .bindMemory(to: sockaddr.self)
            .baseAddress else { fatalError("Never apper here") }

        childSocketFD = accept(socketFD, pointer, &aSockaddrLen)

        guard childSocketFD != -1 else {
            return (nil, childSocketFD)
        }

        return (sock, childSocketFD)
    }

    fileprivate func string(inAddr: UnsafeRawPointer, isIPv4: Bool) -> String? {
//        var addrBuf: [Int8] = []
        let length = Int(isIPv4 ? INET_ADDRSTRLEN : INET6_ADDRSTRLEN)

        guard let addrBuf = malloc(length)?.assumingMemoryBound(to: Int8.self) else { fatalError() }
        memset(addrBuf, 0, length)

        defer {
            free(addrBuf)
        }

        if inet_ntop(isIPv4 ? AF_INET : AF_INET6, inAddr, addrBuf, socklen_t(length)) == nil {
            addrBuf.pointee = 0
        }

        return String(cString: addrBuf, encoding: .utf8)
    }
}

extension sockaddr_un: SocketAddrProtocol {
    var url: URL? {
        var turple = self.sun_path
        var result = withUnsafePointer(to: &turple) {
            $0.withMemoryRebound(to: Int8.self, capacity: 1, { (pointer) -> [Int8] in
                var list: [Int8] = []

                for offset in 0..<104 {
                    list.append((pointer + offset).pointee)
                }
                return list
            })
        }

        let url = String(utf8String: &result) ?? ""

        return URL(string: url)
    }

    var host: String {
        return ""
    }

    var port: UInt16 {
        return 0
    }

    mutating func sun_path_pointer() -> UnsafeMutablePointer<Int8> {
        return withUnsafePointer(to: &(self.sun_path)) {
            $0.withMemoryRebound(to: Int8.self, capacity: 1, {return UnsafeMutablePointer(mutating: $0)})
        }
    }
}

extension sockaddr_in: SocketAddrProtocol {
    var port: UInt16 {
        return CFSwapInt16HostToBig(self.sin_port)
    }

    var host: String {
        var sock = self

        return string(inAddr: &(sock.sin_addr), isIPv4: true) ?? ""
    }

}

extension sockaddr_in6: SocketAddrProtocol {
    var port: UInt16 {
        return CFSwapInt16HostToBig(self.sin6_port)
    }

    var host: String {
        var sock = self

        return string(inAddr: &(sock.sin6_addr), isIPv4: false) ?? ""
    }

    var index: UInt32 {
        var addrs: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&addrs) == 0 else {
            return 0
        }
        guard let firstAddr = addrs else {
            return 0
        }

        defer {
            freeifaddrs(addrs)
        }

        for pointer in sequence(first: firstAddr, next: {$0.pointee.ifa_next}) {
            if pointer.pointee.ifa_addr.pointee.sa_family != AF_INET6 { continue }

            let sock = pointer.pointee.ifa_addr.withMemoryRebound(to: sockaddr_in6.self,
                                                                  capacity: 1, {$0})
            var target = sock.pointee.sin6_addr
            var compare = self.sin6_addr

            if memcmp(&target, &compare, MemoryLayout<in6_addr>.size) == 0 {
                return if_nametoindex(pointer.pointee.ifa_name)
            }
        }

        return 0
    }

    /// Return a MutablePointer of sockaddr_in6
    /// Then can use pointee to change data
    /// Can not just return sockaddr_in6 is because that struct is only value copy.
    /// But we need is to change origin value,not copy value.
    /// 这里我们返回了一个可变指针而不是直接返回sockaddr_in6的原因是因为我们需要修改原有Data中的值，但是结构体的引用是值拷贝。
    /// 因此为了满足需求，将对应的返回值变为指针，使我们能成功修改data内部的值
    /// - Parameter data: A data that contain sockaddr_in6 bytes
    /// - Returns: the pointer of sockaddr_in6
    static func convertFromData(_ data: Data) -> UnsafeMutablePointer<sockaddr_in6>? {
        let length = MemoryLayout.size(ofValue: sockaddr_in6())

        guard data.count == length else { return nil }
        
        
        return data.withUnsafeBytes {
            UnsafeMutablePointer(mutating: $0.bindMemory(to: sockaddr_in6.self).baseAddress!)
        }
    }
}
