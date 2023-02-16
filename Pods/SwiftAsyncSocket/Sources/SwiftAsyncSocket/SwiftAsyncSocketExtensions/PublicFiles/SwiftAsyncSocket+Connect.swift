//
//  SwiftAsyncSocket+Connect.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2018/12/18.
//  Copyright © 2018 chouheiwa. All rights reserved.
//

import Foundation

// MARK: - Connect
extension SwiftAsyncSocket {
    /// Connects to the given host & port, via the optional interface, with an optional timeout.
    ///
    /// The host may be a domain name (e.g. "deusty.com") or an IP address string (e.g. "192.168.0.2").
    /// The host may also be the special strings "localhost" or "loopback" to specify connecting
    /// to a service on the local machine.
    ///
    /// The interface may be a name (e.g. "en1" or "lo0") or the corresponding IP address (e.g. "192.168.4.35").
    /// The interface may also be used to specify the local port (see below).
    ///
    /// To not time out use a negative time interval.
    /// This method will throw an error is detected
    /// Possible errors would be a nil host, invalid interface, or socket is already connected.
    ///
    /// If no errors are detected, this method will start a background connect operation and immediately return YES.
    /// The delegate callbacks are used to notify you when the socket connects, or if the host was unreachable.
    ///
    /// Since this class supports queued reads and writes, you can immediately start reading and/or writing.
    /// All read/write operations will be queued, and upon socket connection,
    /// the operations will be dequeued and processed in order.
    ///
    /// The interface may optionally contain a port number at the end of the string, separated by a colon.
    /// This allows you to specify the local port that should be used for the outgoing connection.
    /// (read paragraph to end)
    /// To specify both interface and local port: "en1:8082" or "192.168.4.35:2424".
    /// To specify only local port: ":8082".
    /// Please note this is an advanced feature, and is somewhat hidden on purpose.
    /// You should understand that 99.999% of the time you should NOT specify the local port for an outgoing connection.
    /// If you think you need to, there is a very good chance you have a fundamental misunderstanding somewhere.
    /// Local ports do NOT need to match remote ports. In fact, they almost never do.
    /// This feature is here for networking professionals using very advanced techniques.
    /// - Parameters:
    ///   - host: connnected host
    ///   - port: connected port
    ///   - interface: limit interface such as "en1:8082" or "192.168.4.35:2424"
    ///   - timeOut: connect timeout (use negative to make no time out)
    /// - Throws: Connect error
    public func connect(toHost host: String,
                        onPort port: UInt16,
                        viaInterface interface: String? = nil,
                        timeOut: TimeInterval = -1) throws {
        var error: SwiftAsyncSocketError?

        socketQueueDo {
            do {
                try self.connectToHost(host, port: port, interface: interface, timeout: timeOut)
            } catch let err as SwiftAsyncSocketError {
                error = err
            } catch {
                fatalError()
            }
        }

        if let error = error {
            throw error
        }
    }

    private func connectToHost(_ host: String, port: UInt16, interface: String?, timeout: TimeInterval) throws {
        // Check for problems with host parameter
        guard host.count > 0 else {
            throw SwiftAsyncSocketError.badConfig(msg: "Invalid host parameter (nil or \"\")." +
                " Should be a domain name or IP address string.")
        }
        // Run through standard pre-connect checks
        try preConnect(interface: interface)
        // We've made it past all the checks.
        // It's time to start the connection process.
        flags.insert(.started)

        let stateIndex = self.stateIndex

        let globalConcurrentQueue =  DispatchQueue.global(qos: .default)

        globalConcurrentQueue.async { [weak self] in
            guard let `self` = self else { return }

            do {
                let dataType = try SocketDataType.lookup(host: host, port: port)

                self.socketQueue.async {
                    self.lookup(stateIndex,
                                didSuccessWith: dataType)
                }

            } catch let error as SwiftAsyncSocketError {
                self.socketQueue.async {
                    self.lookup(stateIndex, fail: error)
                }
            } catch {
                fatalError("\(error)")
            }
        }

        startConnectTimeout(timeout)
    }

    /// Connects to the given address, using the specified interface and timeout.
    ///
    /// The address is specified as a sockaddr structure wrapped in a Data.
    /// For example, a Data object returned from NetService's addresses var.
    ///
    /// If you have an existing struct sockaddr you can convert it to a NSData object like so:
    /// var sa: sockaddr -> let dsa = Data(bytes: &sa, count: sa.sa_len)
    ///
    /// The interface may be a name (e.g. "en1" or "lo0") or the corresponding IP address (e.g. "192.168.4.35").
    /// The interface may also be used to specify the local port (see below).
    ///
    /// The timeout is optional. To not time out use a negative time interval.
    ///
    /// This method will return NO if an error is detected, and set the error pointer (if one was given).
    /// Possible errors would be a nil host, invalid interface, or socket is already connected.
    ///
    /// If no errors are detected, this method will start a background connect operation and immediately return YES.
    /// The delegate callbacks are used to notify you when the socket connects, or if the host was unreachable.
    ///
    /// Since this class supports queued reads and writes, you can immediately start reading and/or writing.
    /// All read/write operations will be queued, and upon socket connection,
    /// the operations will be dequeued and processed in order.
    ///
    /// The interface may optionally contain a port number at the end of the string, separated by a colon.
    /// This allows you to specify the local port that should be used for the outgoing connection.
    /// (read paragraph to end)
    /// To specify both interface and local port: "en1:8082" or "192.168.4.35:2424".
    /// To specify only local port: ":8082".
    ///
    /// - Parameters:
    ///   - toAddress: socket address
    ///   - interface: interface
    ///   - timeout: timeout
    /// - Throws: error
    public func connect(toAddress: Data, viaInterface interface: String? = nil, timeout: TimeInterval = -1) throws {
        var errors: SwiftAsyncSocketError?

        socketQueueDo {
            do {
                try self.connectToAddress(toAddress, viaInterface: interface, timeout: timeout)
            } catch let error as SwiftAsyncSocketError {
                errors = error
            } catch {
                fatalError("Other error")
            }
        }

        if let error = errors {
            throw error
        }
    }

    private func connectToAddress(_ toAddress: Data,
                                  viaInterface interface: String?,
                                  timeout: TimeInterval) throws {
        let dataType = try SocketDataType(data: toAddress)

        switch dataType {
        case .IPv4Data:
            guard isIPv4Enabled else {
                throw SwiftAsyncSocketError.badParamError(
                    "IPv4 has been disabled and an IPv4 address was passed.")
            }
        case .IPv6Data:
            guard isIPv6Enabled else {
                throw SwiftAsyncSocketError.badParamError(
                    "IPv6 has been disabled and an IPv6 address was passed.")
            }
        default:
            break
        }

        try preConnect(interface: interface)

        try connect(withSockData: dataType)

        flags.insert(.started)

        startConnectTimeout(timeout)
    }

    public func connect(toUrl url: URL, timeOut: TimeInterval) throws {
        var errors: SwiftAsyncSocketError?
        socketQueueDo {
            do {
                guard url.path.count > 0 else {
                    throw SwiftAsyncSocketError.badParamError("Invalid unix domain socket url.")
                }
                // 完成
                try self.preConnect(url: url)

                self.flags.insert(.started)
                guard let connectInterfaceUN = self.connectInterfaceUN else { fatalError("Logic error") }
                try self.connect(withAddressUN: connectInterfaceUN)

                self.startConnectTimeout(timeOut)
            } catch let error as SwiftAsyncSocketError {
                errors = error
            } catch {
                fatalError("\(error)")
            }
        }
        if let error = errors {
            throw error
        }
    }

    private func connect(withAddressUN address: Data) throws {
        assert(DispatchQueue.getSpecific(key: queueKey) != nil)

        let socketFD = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)

        socketUN = socketFD

        guard socketFD != SwiftAsyncSocketKeys.socketNull else {
            throw SwiftAsyncSocketError.errno(code: errno,
                                              reason: "Error in socket() function")
        }

        var reuseOn = 1

        Darwin.setsockopt(socketFD,
                          Darwin.SOL_SOCKET,
                          Darwin.SO_REUSEADDR,
                          &reuseOn,
                          Darwin.socklen_t(MemoryLayout.size(ofValue: reuseOn)))

        // Prevent SIGPIPE signals to ignore crash

        var nosigpipe = 1

        Darwin.setsockopt(socketFD,
                          SOL_SOCKET,
                          SO_NOSIGPIPE,
                          &nosigpipe,
                          socklen_t(MemoryLayout.size(ofValue: nosigpipe)))

        let aStateIndex = stateIndex

        DispatchQueue.global().async {
            let pointer: UnsafePointer<sockaddr> = address.convert()

            let result = Darwin.connect(socketFD, pointer, socklen_t(pointer.pointee.sa_len))

            guard result == 0 else {
                perror("connect".withCString({$0}))
                self.socketQueue.async {
                    self.didNotConnect(aStateIndex,
                                       error: SwiftAsyncSocketError.errno(code: errno,
                                                                          reason: "Error in connect() function"))
                }
                return
            }

            self.socketQueue.async {
                self.didConnect(aStateIndex)
            }
        }
    }
}
