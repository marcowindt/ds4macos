//
//  SwiftAsyncSocket.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2018/12/7.
//  Copyright © 2018 chouheiwa. All rights reserved.
//

import Foundation

struct SwiftAsyncSocketKeys {
    static let socketNull: Int32 = -1
    static let socketQueueName: String = "SwiftAsyncSocket"
    static let asyncSocketThreadName: String = "SwiftAsyncSocket-CFStream"

    static let threadQueueName: String = "SwiftAsyncSocket-CFStreamThreadSetup"
    init() {}
}

public class SwiftAsyncSocket: NSObject {

    var flags: SwiftAsyncSocketFlags = []
    var config: SwiftAsyncSocketConfig = []
    /// Real storable delagate
    weak var delegateStore: SwiftAsyncSocketDelegate?

    var delegateQueueStore: DispatchQueue?

    public internal(set) var socket4FD: Int32 = SwiftAsyncSocketKeys.socketNull

    public internal(set) var socket6FD: Int32 = SwiftAsyncSocketKeys.socketNull

    public internal(set) var socketUN: Int32 = SwiftAsyncSocketKeys.socketNull

    var socketURL: URL?

    var stateIndex: Int = 0

    var connectInterface4: Data?

    var connectInterface6: Data?

    var connectInterfaceUN: Data?

    var socketQueue: DispatchQueue

    var accept4Source: DispatchSourceRead?

    var accept6Source: DispatchSourceRead?

    var acceptUNSource: DispatchSourceRead?

    var connectTimer: DispatchSourceTimer?

    var readSource: DispatchSourceRead?

    var writeSource: DispatchSourceWrite?

    var readTimer: DispatchSourceTimer?

    var writeTimer: DispatchSourceTimer?

    var readQueue: [SwiftAsyncPacketProtocol] = []

    var writeQueue: [SwiftAsyncPacketProtocol] = []

    var currentRead: SwiftAsyncPacketProtocol?

    var currentWrite: SwiftAsyncPacketProtocol?

    var socketFDBytesAvailable: UInt = 0

    var preBuffer: SwiftAsyncSocketBuffer
    #if os(iOS)
    var streamContext: CFStreamClientContext = CFStreamClientContext()

    var readStream: CFReadStream?

    var writeStream: CFWriteStream?
    #endif
    var sslContext: SSLContext?

    var sslPreBuffer: SwiftAsyncSocketBuffer?

    var sslWriteCachedLength: size_t = 0

    var sslErrCode: OSStatus = 0

    var lastSSLHandshakeError: OSStatus = 0

    let queueKey: DispatchSpecificKey<SwiftAsyncSocket> = DispatchSpecificKey<SwiftAsyncSocket>()

    var userDataStore: Any?

    var alternateAddressDelayStore: TimeInterval = 0

    public init(delegate: SwiftAsyncSocketDelegate? = nil,
                delegateQueue: DispatchQueue? = nil,
                socketQueue: DispatchQueue? = nil) {
        delegateStore = delegate

        delegateQueueStore = delegateQueue

        if let socketQueue = socketQueue {
            assert(socketQueue != DispatchQueue.global(qos: .utility),
                   SwiftAsyncSocketAssertError.queueLevel.description)
            assert(socketQueue != DispatchQueue.global(qos: .userInitiated),
                   SwiftAsyncSocketAssertError.queueLevel.description)
            assert(socketQueue != DispatchQueue.global(qos: .default),
                   SwiftAsyncSocketAssertError.queueLevel.description)

            self.socketQueue = socketQueue
        } else {
            self.socketQueue = DispatchQueue(label: SwiftAsyncSocketKeys.socketQueueName)
        }

        preBuffer = SwiftAsyncSocketPreBuffer(capacity: 4 * 1024)

        super.init()

        self.socketQueue.setSpecific(key: queueKey, value: self)
    }

    deinit {
        flags.insert(.dealloc)

        socketQueueDo {
            self.closeSocket(error: nil)
        }

        delegate = nil
        delegateQueue = nil
    }
}
// MARK: - init Function
extension SwiftAsyncSocket {
    convenience init(from connectedSocketFD: Int32,
                     delegate: SwiftAsyncSocketDelegate? = nil,
                     delegateQueue: DispatchQueue?,
                     socketQueue: DispatchQueue?) throws {
        self.init(delegate: delegate, delegateQueue: delegateQueue, socketQueue: socketQueue)

        try self.socketQueue.sync {
            var addr: sockaddr = sockaddr()

            var addrSize = socklen_t(MemoryLayout.size(ofValue: addr))

            let result = Darwin.getpeername(connectedSocketFD, &addr, &addrSize)

            guard result == 0 else {
                throw SwiftAsyncSocketError(msg: "Attempt to create socket from socket FD failed. getpeername() failed")
            }

            if addr.sa_family == Darwin.AF_INET {
                socket4FD = connectedSocketFD
            } else if addr.sa_family == AF_INET6 {
                socket6FD = connectedSocketFD
            } else {
                throw SwiftAsyncSocketError(msg:
                    "Attempt to create socket from socket FD failed. socket FD is neither IPv4 nor IPv6")
            }

            flags = .started
            didConnect(stateIndex)
        }
    }

}
