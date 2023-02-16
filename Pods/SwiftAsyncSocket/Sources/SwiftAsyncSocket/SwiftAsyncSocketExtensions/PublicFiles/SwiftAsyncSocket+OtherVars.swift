//
//  SwiftAsyncSocket+OtherVar.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2018/12/13.
//  Copyright © 2018 chouheiwa. All rights reserved.
//

import Foundation

// MARK: - Some Public Config Vars
extension SwiftAsyncSocket {

    public weak var delegate: SwiftAsyncSocketDelegate? {
        get {
            var result: SwiftAsyncSocketDelegate?

            socketQueueDo {
                result = self.delegateStore
            }
            return result
        }
        set {
            socketQueueDo(sync: false) {
                self.delegateStore = newValue
            }
        }
    }

    public var delegateQueue: DispatchQueue? {
        get {
            var result: DispatchQueue?

            socketQueueDo {
                result = self.delegateQueueStore
            }
            return result
        }
        set {
            socketQueueDo(sync: false) {
                self.delegateQueueStore = newValue
            }
        }
    }

    /// Set this property to enable or disable IPv4
    public var isIPv4Enabled: Bool {
        get {
            var result = false
            socketQueueDo {
                result = !self.config.contains(.IPv4Disabled)
            }
            return result
        }
        set {
            socketQueueDo(sync: false) {
                if !newValue {
                    self.config.insert(.IPv4Disabled)
                } else {
                    self.config.remove(.IPv4Disabled)
                }
            }
        }
    }
    /// Set this property to enable or disable IPv6
    public var isIPv6Enabled: Bool {
        get {
            var result = false
            socketQueueDo {
                result = !self.config.contains(.IPv6Disabled)
            }
            return result
        }
        set {
            socketQueueDo(sync: false) {
                if !newValue {
                    self.config.insert(.IPv6Disabled)
                } else {
                    self.config.remove(.IPv6Disabled)
                }
            }
        }
    }

    /// we used ipv4 first or ipv6
    public var isIPv4PreferredOverIPv6: Bool {
        get {
            var result = false
            socketQueueDo {
                result = !self.config.contains(.preferIPv6)
            }
            return result
        }
        set {
            socketQueueDo(sync: false) {
                if !newValue {
                    self.config.insert(.preferIPv6)
                } else {
                    self.config.remove(.preferIPv6)
                }
            }
        }
    }

    public var alternateAddressDelay: TimeInterval {
        get {
            var timerInterval: TimeInterval = 0

            socketQueueDo {
                timerInterval = self.alternateAddressDelayStore
            }

            return timerInterval
        }
        set {
            socketQueueDo(sync: false) {
                self.alternateAddressDelayStore = newValue
            }
        }
    }

    public var userData: Any? {
        get {
            var result: Any?

            socketQueueDo {
                result = self.userDataStore
            }

            return result
        }
        set {
            socketQueueDo(sync: false) {
                self.userDataStore = newValue
            }
        }
    }
}

// MARK: - Diagnostics
extension SwiftAsyncSocket {
    public var isDisconnected: Bool {
        var result = false

        socketQueueDo {
            result = !self.flags.contains(.started)
        }

        return result
    }

    public var isConnected: Bool {
        var result = false

        socketQueueDo {
            result = self.flags.contains(.connected)
        }

        return result
    }

    public var connectedHost: String? {
        var host: String?

        socketQueueDo {
            if self.socket4FD != SwiftAsyncSocketKeys.socketNull {
                host = sockaddr_in.getPeerSocketFD(self.socket4FD)?.host
                return
            }
            if self.socket6FD != SwiftAsyncSocketKeys.socketNull {
                host = sockaddr_in6.getPeerSocketFD(self.socket6FD)?.host
                return
            }
        }

        return host
    }

    public var connectedPort: UInt16 {
        var port: UInt16 = 0

        socketQueueDo {
            if self.socket4FD != SwiftAsyncSocketKeys.socketNull {
                port = sockaddr_in.getPeerSocketFD(self.socket4FD)?.port ?? 0
                return
            }
            if self.socket6FD != SwiftAsyncSocketKeys.socketNull {
                port = sockaddr_in6.getPeerSocketFD(self.socket6FD)?.port ?? 0
                return
            }
        }

        return port
    }

    public var connectedURL: URL? {
        var result: URL?

        socketQueueDo {
            if self.socketUN != SwiftAsyncSocketKeys.socketNull {
                result = sockaddr_un.getPeerSocketFD(self.socketUN)?.url
            }
        }

        return result
    }

    public var localHost: String? {
        var host: String?

        socketQueueDo {
            if self.socket4FD != SwiftAsyncSocketKeys.socketNull {
                host = sockaddr_in.getLocalSocketFD(self.socket4FD)?.host
                return
            }
            if self.socket6FD != SwiftAsyncSocketKeys.socketNull {
                host = sockaddr_in6.getLocalSocketFD(self.socket6FD)?.host
                return
            }
        }

        return host
    }

    public var localPort: UInt16 {
        var port: UInt16 = 0

        socketQueueDo {
            if self.socket4FD != SwiftAsyncSocketKeys.socketNull {
                port = sockaddr_in.getLocalSocketFD(self.socket4FD)?.port ?? 0
                return
            }
            if self.socket6FD != SwiftAsyncSocketKeys.socketNull {
                port = sockaddr_in6.getLocalSocketFD(self.socket6FD)?.port ?? 0
                return
            }
        }

        return port
    }

    public var connectedAddress: Data? {
        var data: Data?

        socketQueueDo {
            if self.socket4FD != SwiftAsyncSocketKeys.socketNull {
                if var sock = sockaddr_in.getPeerSocketFD(self.socket4FD) {
                    data = Data(bytes: &sock, count: MemoryLayout.size(ofValue: sock))
                }
            }

            if self.socket6FD != SwiftAsyncSocketKeys.socketNull {
                if var sock = sockaddr_in6.getPeerSocketFD(self.socket6FD) {
                    data = Data(bytes: &sock, count: MemoryLayout.size(ofValue: sock))
                }
            }
        }
        return data
    }

    public var localAddress: Data? {
        var data: Data?

        socketQueueDo {
            if self.socket4FD != SwiftAsyncSocketKeys.socketNull {
                if var sock = sockaddr_in.getLocalSocketFD(self.socket4FD) {
                    data = Data(bytes: &sock, count: MemoryLayout.size(ofValue: sock))
                }
            }

            if self.socket6FD != SwiftAsyncSocketKeys.socketNull {
                if var sock = sockaddr_in6.getLocalSocketFD(self.socket6FD) {
                    data = Data(bytes: &sock, count: MemoryLayout.size(ofValue: sock))
                }
            }
        }

        return data
    }

    public var isIPv4: Bool {
        var result = false

        socketQueueDo {
            result = self.socket4FD != SwiftAsyncSocketKeys.socketNull
        }

        return result
    }

    public var isIPv6: Bool {
        var result = false

        socketQueueDo {
            result = self.socket6FD != SwiftAsyncSocketKeys.socketNull
        }

        return result
    }

    public var isSecure: Bool {
        var result = false

        socketQueueDo {
            result = self.flags.contains(.isSecure)
        }
        return result
    }
}

// MARK: - Advanced
extension SwiftAsyncSocket {
    public var autoDisconnectOnClosedReadStream: Bool {
        get {
            var result = false
            socketQueueDo {
                result = !self.config.contains(.allowHalfDuplexConnection)
            }
            return result
        }
        set {
            socketQueueDo {
                if newValue {
                    self.config.remove(.allowHalfDuplexConnection)
                } else {
                    self.config.insert(.allowHalfDuplexConnection)
                }
            }
        }
    }
}

extension SwiftAsyncSocket {
    var currentSocketFD: Int32 {
        return (socket4FD != SwiftAsyncSocketKeys.socketNull) ?
            socket4FD :
            (socket6FD != SwiftAsyncSocketKeys.socketNull) ?
                socket6FD : socketUN
    }

    var isUsingCFStreamForTLS: Bool {
        #if os(iOS)
        if flags.contains([.isSecure, .isUsingCFStreamForTLS]) {
            return true
        }
        #endif

        return false
    }

    var isUsingSecureTransportForTLS: Bool {
        #if os(iOS)
        if flags.contains([.isSecure, .isUsingCFStreamForTLS]) {
            return false
        }
        #endif

        return true
    }

    var localPort4: UInt16 {
        return sockaddr_in.getLocalSocketFD(socket4FD)?.port ?? 0
    }
}
