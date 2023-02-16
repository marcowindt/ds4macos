//
//  SwiftAsyncSocket+Accepting.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2018/12/17.
//  Copyright © 2018 chouheiwa. All rights reserved.
//

import Foundation

// MARK: - Accepting
extension SwiftAsyncSocket {

    /// Tells the socket to begin listening and accepting connections on the given port.
    /// When a connection is accepted,
    /// a new instance of SwiftAsyncSocket will be spawned to handle it,
    /// and the socket(_ socket: SwiftAsyncSocket, didAccept newSocket: SwiftAsyncSocket)
    /// delegate method will be called
    /// The socket only listen on interface you specified,
    /// if the interface is nil, the socket will listen on all available interfaces
    /// (e.g. wifi, ethernet, etc)
    ///
    /// - Parameters:
    ///   - interface: the interface is controled that who can connect
    ///   if you use "localhost" then only local socket can connect
    ///   - port: listen port
    /// - Returns: Accept status
    /// - Throws: if accepted was wrong then error will throw
    public func accept(onInterFace interface: String? = nil, port: UInt16) throws -> Bool {
        return try accept(type: .interface(interface, port: port))
    }

    /// Tells the socket to begin listening and
    /// accepting connections on the unix domain at the given url.
    ///
    /// - Parameter url: url
    /// - Returns: Accept status
    /// - Throws: if accepted was wrong then error will throw
    public func accept(onUrl url: URL) throws -> Bool {
        return try accept(type: .url(url))
    }

    private func accept(type: AcceptType) throws -> Bool {
        var result = false
        var error: SwiftAsyncSocketError?

        socketQueueDo {
            do {
                result = try self.acceptDone(type: type)
            } catch let err as SwiftAsyncSocketError {
                error = err
            } catch {
                fatalError("\(error)")
            }
        }

        if let error = error {
            throw error
        }

        return result
    }

    private enum SocketType {
        case ipv4
        case ipv6
        case ipun
    }
    private func doAccept(_ parentSocketFD: Int32) -> Bool {
        var socketType: SocketType
        var childSocketFD: Int32 = 0
        var childSocketAddress: Data

        if parentSocketFD == socket4FD {
            socketType = .ipv4
            var addr: sockaddr_in?
            (addr, childSocketFD) = sockaddr_in.getAcceptSocketFD(parentSocketFD)
            guard var addrs = addr else { return false }

            childSocketAddress = Data(bytes: &addrs, count: MemoryLayout.size(ofValue: addr))
        } else if parentSocketFD == socket6FD {
            socketType = .ipv6

            var addr: sockaddr_in6?
            (addr, childSocketFD) = sockaddr_in6.getAcceptSocketFD(parentSocketFD)
            guard var addrs = addr else { return false }

            childSocketAddress = Data(bytes: &addrs, count: MemoryLayout.size(ofValue: addr))
        } else {
            socketType = .ipun

            var addr: sockaddr_in?
            (addr, childSocketFD) = sockaddr_in.getAcceptSocketFD(parentSocketFD)
            guard var addrs = addr else { return false }

            childSocketAddress = Data(bytes: &addrs, count: MemoryLayout.size(ofValue: addr))
        }
        // public func fcntl(_ fd: Int32, _ cmd: Int32, _ ptr: UnsafeMutableRawPointer) -> Int32
        // public func fcntl(_ fd: Int32, _ cmd: Int32, _ value: Int32) -> Int32
        // public func fcntl(_ fd: Int32, _ cmd: Int32) -> Int32
        // fcntl() has these three functions
        // We only want to set socket to nonblock so that we can connect|read|write async
        let flags = Darwin.fcntl(childSocketFD, F_GETFL, 0)
        let result = Darwin.fcntl(childSocketFD, F_SETFL, flags | O_NONBLOCK)

        guard result != -1 else {
            Darwin.close(childSocketFD)
            return false
        }

        var noSigPipe = 1

        Darwin.setsockopt(childSocketFD, SOL_SOCKET, SO_NOSIGPIPE,
                          &noSigPipe,
                          socklen_t(MemoryLayout.size(ofValue: noSigPipe)))

        doAceptCallDelegate(childSocketAddress: childSocketAddress,
                            socketType: socketType,
                            childSocketFD: childSocketFD)

        return true
    }

    private func doAceptCallDelegate(childSocketAddress: Data,
                                     socketType: SocketType,
                                     childSocketFD: Int32) {
        delegateQueue?.async {
            let childSocketQueue = self.delegate?.newSocketQueueForConnection(from: childSocketAddress,
                                                                              on: self)

            let acceptedSocket = SwiftAsyncSocket(delegate: self.delegate,
                                                  delegateQueue: self.delegateQueue,
                                                  socketQueue: childSocketQueue)

            switch socketType {
            case .ipv4:
                acceptedSocket.socket4FD = childSocketFD
            case .ipv6:
                acceptedSocket.socket4FD = childSocketFD
            case .ipun:
                acceptedSocket.socketUN = childSocketFD
            }

            acceptedSocket.flags.insert([.started, .connected])
            // Setup read and write sources for accepted socket
            acceptedSocket.socketQueue.async {
                acceptedSocket.setupReadAndWritesSources(forNewlyConnectedSocket: childSocketFD)
            }
            // Notify delegate
            self.delegate?.socket(self, didAccept: acceptedSocket)
            // The accepted socket should have been retained by the delegate.
            // Otherwise it gets properly released when exiting the block.
        }
    }
}

extension SwiftAsyncSocket {
    fileprivate enum AcceptType {
        case interface(_ interface: String?, port: UInt16)
        case url(_ url: URL)
    }

    private func acceptDone(type: AcceptType) throws -> Bool {
        try acceptDoneGuard(method: "accept")

        self.readQueue.removeAll()
        self.writeQueue.removeAll()

        switch type {
        case .interface(let interface, let port):
            guard try acceptInterfaceNeedDone(interface, port: port) else { return false }
        case .url(let url):
            let interface = try acceptDoneUrlGuard(url: url)

            socketUN = try createSocket(domain: AF_UNIX, interfaceAddr: interface)

            let acceptSource = DispatchSource.makeReadSource(fileDescriptor: socketUN,
                                                             queue: socketQueue)

            acceptUNSource = acceptSource
            let socketFD = socketUN

            acceptDoneDoSetupReader(acceptSource: acceptSource, socketFD: socketFD)
        }

        self.flags.insert(.started)
        return true
    }

    private func acceptInterfaceNeedDone(_ interface: String?, port: UInt16) throws -> Bool {
        let type = try acceptDoneInterfaceGuard(interface: interface, port: port)

        var ipv4Enable = false
        var ipv6Enable = false

        let createSocket4Block: (Data) throws -> Bool = { (interface4: Data) in
            self.socket4FD = try self.createSocket(domain: AF_INET, interfaceAddr: interface4)

            guard self.socket4FD != SwiftAsyncSocketKeys.socketNull else { return false }
            ipv4Enable = true
            return true
        }

        let createSocket6Block: (Data) throws -> Bool = { (interface6: Data) in
            if self.isIPv4Enabled && port == 0 {
                guard let addr6 = sockaddr_in6.convertFromData(interface6) else {
                    assert(false, "Logic Error Here")
                    fatalError("Logic Error Here")
                }

                addr6.pointee.sin6_port = CFSwapInt16HostToBig(self.localPort4)
            }

            self.socket6FD = try self.createSocket(domain: AF_INET6, interfaceAddr: interface6)

            guard self.socket6FD != SwiftAsyncSocketKeys.socketNull else {
                if self.socket4FD != SwiftAsyncSocketKeys.socketNull {
                    Darwin.close(self.socket4FD)
                }
                return false
            }
            ipv6Enable = true
            return true
        }

        switch type {
        case .IPv4Data(let data):
            guard try createSocket4Block(data) else {
                return false
            }
        case .IPv6Data(let data):
            guard try createSocket6Block(data) else {
                return false
            }
        case .bothData(let ipv4, let ipv6):
            guard try createSocket4Block(ipv4) else {
                return false
            }
            guard try createSocket6Block(ipv6) else {
                return false
            }
        }

        if ipv4Enable {
            let acceptSource = DispatchSource.makeReadSource(fileDescriptor: socket4FD,
                                                             queue: socketQueue)

            accept4Source = acceptSource

            let socketFD = socket4FD

            acceptDoneDoSetupReader(acceptSource: acceptSource, socketFD: socketFD)
        }

        if ipv6Enable {
            let acceptSource = DispatchSource.makeReadSource(fileDescriptor: socket6FD,
                                                             queue: socketQueue)

            accept6Source = acceptSource
            let socketFD = socket6FD

            acceptDoneDoSetupReader(acceptSource: acceptSource, socketFD: socketFD)
        }

        return true
    }

    func acceptDoneGuard(method: String) throws {
        guard delegate != nil else {
            throw SwiftAsyncSocketError.badConfig(msg:
                "Attempting to \(method) without a delegate. Set a delegate first.")
        }

        guard delegateQueue != nil else {
            throw SwiftAsyncSocketError.badConfig(msg:
                "Attempting to \(method) without a delegate. Set a delegate first.")
        }

        guard self.isIPv6Enabled || self.isIPv4Enabled else {
            throw SwiftAsyncSocketError.badConfig(msg:
                "Both IPv4 and IPv6 have been disabled. Must enable at least one protocol first.")
        }

        guard self.isDisconnected else {
            throw SwiftAsyncSocketError.badConfig(msg:
                "Attempting to \(method) while connected or accepting connections. Disconnect first.")
        }
    }

    func acceptDoneInterfaceGuard(interface: String?, port: UInt16) throws -> SocketDataType {
        guard let type = SocketDataType.getInterfaceAddress(interface: interface ?? "",
                                                            port: port) else {
            throw SwiftAsyncSocketError.badParamError(
                "Unknown interface. Specify valid interface by name (e.g. \"en1\") or IP address.")
        }
        switch type {
        case .IPv4Data:
            guard isIPv4Enabled else {
                throw SwiftAsyncSocketError.badParamError(
                    "IPv4 has been disabled and specified interface doesn't support IPv6.")
            }
        case .IPv6Data:
            guard isIPv6Enabled else {
                throw SwiftAsyncSocketError.badParamError(
                    "IPv6 has been disabled and specified interface doesn't support IPv4.")
            }
        default:
            break
        }

        return type
    }

    private func acceptDoneUrlGuard(url: URL?) throws -> Data {
        guard let url = url else {
            throw SwiftAsyncSocketError.badParamError("Invalid unix domain url." +
                " Specify a valid file url that does not exist (e.g. \"file:///tmp/socket\")") }

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: url.path) {
            do {
                try fileManager.removeItem(at: url)
            } catch {
                throw SwiftAsyncSocketError(msg: "Could not remove previous unix domain socket at given url.")
            }
        }

        guard let interface = getInterfaceAddress(url: url) else { throw
            SwiftAsyncSocketError.badParamError("Invalid unix domain url." +
                 " Specify a valid file url that does not exist (e.g. \"file:///tmp/socket\")")
        }

        return interface
    }

    private func acceptDoneDoSetupReader(acceptSource: DispatchSourceRead, socketFD: Int32) {
        acceptSource.setEventHandler(handler: { [weak self] in
            guard let `self` = self else { return }
            var count: UInt = 0
            let numPendingConnections = acceptSource.data
            while self.doAccept(socketFD) && (count < numPendingConnections) {
                count += 1
            }
        })

        acceptSource.setCancelHandler(handler: {
            Darwin.close(socketFD)
        })
        acceptSource.resume()
    }

    private func createSocket(domain: Int32, interfaceAddr: Data) throws -> Int32 {
        let socketFD = Darwin.socket(domain, SOCK_STREAM, 0)

        guard socketFD != SwiftAsyncSocketKeys.socketNull else {
            throw SwiftAsyncSocketError.errno(code: errno, reason: "Error in socket() function")
        }

        var status = Darwin.fcntl(socketFD, F_SETFL, O_NONBLOCK)

        guard status != -1 else {
            Darwin.close(socketFD)
            throw SwiftAsyncSocketError.errno(code: errno,
                                              reason: "Error enabling non-blocking IO on socket (fcntl)")
        }

        var resultOn = 1

        status = setsockopt(socketFD,
                            SOL_SOCKET,
                            SO_REUSEADDR,
                            &resultOn,
                            socklen_t(MemoryLayout.size(ofValue: resultOn)))

        guard status != -1 else {
            Darwin.close(socketFD)
            throw SwiftAsyncSocketError.errno(code: errno,
                                              reason: "Error enabling address reuse (setsockopt)")
        }

        status = Darwin.bind(socketFD, interfaceAddr.convert(), socklen_t(interfaceAddr.count))

        guard status != -1 else {
            Darwin.close(socketFD)
            throw SwiftAsyncSocketError.errno(code: errno,
                                              reason: "Error in bind() function")
        }

        status = Darwin.listen(socketFD, 1024)

        guard status != -1 else {
            Darwin.close(socketFD)
            throw SwiftAsyncSocketError.errno(code: errno, reason: "Error in listen() function")
        }

        return socketFD
    }
}
