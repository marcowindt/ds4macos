//
//  SwiftAsyncSocket+ConnectStatus.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2019/1/8.
//  Copyright © 2019 chouheiwa. All rights reserved.
//

import Foundation

extension SwiftAsyncSocket {
    func connect(withSockData sockDataType: SocketDataType) throws {
        assert(DispatchQueue.getSpecific(key: queueKey) != nil)

        let createSock4 = {
            self.socket4FD = try self.createSock(.IPv4, connectinterface: self.connectInterface4)
        }
        let createSock6 = {
            self.socket6FD = try self.createSock(.IPv6, connectinterface: self.connectInterface6)
        }
        switch sockDataType {
        case .IPv4Data(let ipv4):
            try createSock4()
            connectSock(socket4FD, address: ipv4, stateIndex: stateIndex)
        case .IPv6Data(let ipv6):
            try createSock6()
            connectSock(socket6FD, address: ipv6, stateIndex: stateIndex)
        case .bothData(let ipv4, let ipv6):
            try createSock4()
            try createSock6()

            let socketFD = isIPv4PreferredOverIPv6 ? socket4FD : socket6FD
            let alternateSocketFD = isIPv4PreferredOverIPv6 ? socket6FD : socket4FD
            let address = isIPv4PreferredOverIPv6 ? ipv4 : ipv6
            let alternateAddress = isIPv4PreferredOverIPv6 ? ipv6 : ipv4

            let aStateIndex = stateIndex
            connectSock(socketFD, address: address, stateIndex: aStateIndex)
            socketQueue.asyncAfter(deadline: DispatchTime.now() + alternateAddressDelay, execute: {
                self.connectSock(alternateSocketFD, address: alternateAddress, stateIndex: aStateIndex)
            })
        }
    }

    func didConnect(_ aStateIndex: Int) {
        assert(DispatchQueue.getSpecific(key: queueKey) != nil,
               SwiftAsyncSocketAssertError.socketQueueAction.description)

        guard aStateIndex == self.stateIndex else {
            return
        }

        flags.insert(.connected)

        endConnectTimeout()

        let changedIndex = self.stateIndex

        let host = connectedHost
        let port = connectedPort
        let url = connectedURL

        if let delegateQueue = delegateQueue {
            if let host = host {
                setupStreamsPart1()
                delegateQueue.async {
                    self.delegate?.socket(self, didConnect: host, port: port)

                    self.socketQueue.async {
                        self.setupStreamsPart2(changedIndex: changedIndex)
                    }
                }
            } else if let url = url {
                setupStreamsPart1()
                delegateQueue.async {
                    self.delegate?.socket(self, didConnect: url)

                    self.socketQueue.async {
                        self.setupStreamsPart2(changedIndex: changedIndex)
                    }
                }
            }
        } else {
            setupStreamsPart1()
            setupStreamsPart2(changedIndex: changedIndex)
        }

        guard Darwin.fcntl(currentSocketFD, F_SETFL, O_NONBLOCK) != -1 else {
            closeSocket(error: SwiftAsyncSocketError(msg: "Error enabling non-blocking IO on socket (fcntl)"))
            return
        }

        setupReadAndWritesSources(forNewlyConnectedSocket: currentSocketFD)

        maybeDequeueRead()
        maybeDequeueWrite()
    }

    private func setupStreamsPart1() {
        #if os(iOS)
        guard createReadWriteStream() else {
            closeSocket(error: SwiftAsyncSocketError(msg: "Error creating CFStreams"))
            return
        }
        guard registerForStreamCallbacks(including: false) else {
            closeSocket(error: SwiftAsyncSocketError(msg: "Error in CFStreamSetClient"))
            return
        }
        #endif
    }

    private func setupStreamsPart2(changedIndex: Int) {
        #if os(iOS)
        guard changedIndex == stateIndex else {
            return
        }

        guard addStreamsToRunloop() else {
            closeSocket(error: SwiftAsyncSocketError(msg: "Error in CFStreamScheduleWithRunLoop"))
            return
        }

        guard self.openStreams() else {
            closeSocket(error: SwiftAsyncSocketError(msg: "Error creating CFStreams"))
            return
        }
        #endif
    }

    func didNotConnect(_ aStateIndex: Int, error: SwiftAsyncSocketError) {
        assert(DispatchQueue.getSpecific(key: queueKey) != nil, "Must be dispatched on socketQueue")

        guard aStateIndex == stateIndex else {
            return
        }

        closeSocket(error: error)
    }

    func startConnectTimeout(_ timeout: TimeInterval) {
        guard timeout >= 0.0 else { return }

        connectTimer = DispatchSource.makeTimerSource(flags: [], queue: socketQueue)

        connectTimer?.setEventHandler(handler: { [weak self] in
            guard let `self` = self else { return }

            self.doConnectTimeout()
        })

        connectTimer?.schedule(deadline: DispatchTime.now() + timeout)

        connectTimer?.resume()
    }

    func endConnectTimeout() {
        if let connectTimer = connectTimer {
            connectTimer.cancel()
            self.connectTimer = nil
        }
        // Increment stateIndex.
        // This will prevent us from processing results from any related background asynchronous operations.
        //
        // Note: This should be called from close method even if connectTimer is nil.
        // This is because one might disconnect a socket prior to a successful connection which had no timeout.
        stateIndex += 1

        connectInterface4 = nil

        connectInterface6 = nil
    }

    func doConnectTimeout() {
        endConnectTimeout()
        closeSocket(error: SwiftAsyncSocketError.connectTimeoutError)
    }
}
