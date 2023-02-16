//
//  SwiftAsyncUDPSocket+OtherVars.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2019/1/11.
//  Copyright © 2019 chouheiwa. All rights reserved.
//
import Foundation
// MARK: - Configuration
extension SwiftAsyncUDPSocket {
    public weak var delegate: SwiftAsyncUDPSocketDelegate? {
        get {
            var delegate: SwiftAsyncUDPSocketDelegate?
            socketQueueDo {
                delegate = self.delegateStore
            }
            return delegate
        }

        set {
            socketQueueDo(async: false, {
                self.delegateStore = newValue
            })
        }
    }

    public var delegateQueue: DispatchQueue? {
        get {
            var delegate: DispatchQueue?
            socketQueueDo {
                delegate = self.delegateQueueStore
            }
            return delegate
        }

        set {
            socketQueueDo(async: false, {
                self.delegateQueueStore = newValue
            })
        }
    }

    /// Default is true
    public var isIPv4Enable: Bool {
        get {
            var result = false

            socketQueueDo {
                result = !self.config.contains(.IPv4Disabled)
            }
            return result
        }

        set {
            socketQueueDo(async: false) {
                if newValue {
                    self.config.remove(.IPv4Disabled)
                } else {
                    self.config.insert(.IPv4Disabled)
                }
            }
        }
    }
    /// Default is true
    public var isIPv6Enable: Bool {
        get {
            var result = false

            socketQueueDo {
                result = !self.config.contains(.IPv6Disabled)
            }
            return result
        }

        set {
            socketQueueDo(async: false) {
                if newValue {
                    self.config.remove(.IPv6Disabled)
                } else {
                    self.config.insert(.IPv6Disabled)
                }
            }
        }
    }

    public var isIPv4Preferred: Bool {
        get {
            var result = false

            socketQueueDo {
                result = self.config.contains(.preferIPv4)
            }
            return result
        }

        set {
            socketQueueDo(async: false) {
                if newValue {
                    self.config.insert(.preferIPv4)
                } else {
                    self.config.remove(.preferIPv4)
                }
            }
        }
    }

    public var isIPv6Preferred: Bool {
        get {
            var result = false

            socketQueueDo {
                result = self.config.contains(.preferIPv6)
            }
            return result
        }

        set {
            socketQueueDo(async: false) {
                if newValue {
                    self.config.insert(.preferIPv6)
                } else {
                    self.config.remove(.preferIPv6)
                }
            }
        }
    }

    public var isIPVersionNeutral: Bool {
        get {
            var result = false

            socketQueueDo {
                result = self.config.contains([.preferIPv4, .preferIPv6]) ||
                    (!self.config.contains(.preferIPv4) && !self.config.contains(.preferIPv6))
            }
            return result
        }

        set {
            guard newValue else {
                assert(false, "IPVersion Neutral can only set to true")
                return
            }

            socketQueueDo(async: false, {
                self.config.insert([.preferIPv4, .preferIPv6])
            })
        }
    }

    public var maxReceiveIPv4BufferSize: Int16 {
        get {
            var result: Int16 = 0

            socketQueueDo {
                result = self.max4ReceiveSizeStore
            }
            return result
        }
        set {
            socketQueueDo(async: false, {
                self.max4ReceiveSizeStore = newValue
            })
        }
    }

    public var maxReceiveIPv6BufferSize: Int32 {
        get {
            var result: Int32 = 0

            socketQueueDo {
                result = self.max6ReceiveSizeStore
            }
            return result
        }
        set {
            socketQueueDo(async: false, {
                self.max6ReceiveSizeStore = newValue
            })
        }
    }

    /// If you want to change the max size,
    /// You must set this before create socket
    /// otherwise it won't work
    public var maxSendBufferSize: Int16 {
        get {
            var result: Int16 = 0

            socketQueueDo {
                result = self.maxSendSizeStore
            }
            return result
        }
        set {
            socketQueueDo(async: false, {
                self.maxSendSizeStore = newValue
            })
        }
    }

    /// userData will only be used for you to identifier the socket,
    /// In other words, the data will not be used by socket
    public var userData: Any? {
        get {
            var result: Any?

            socketQueueDo {
                result = self.userDataStore
            }
            return result
        }
        set {
            socketQueueDo(async: false, {
                self.userDataStore = newValue
            })
        }
    }
}
// MARK: - Diagnostics
extension SwiftAsyncUDPSocket {
    public var cachedLocalAddress4: SwiftAsyncUDPSocketAddress? {
        get {
            var result: SwiftAsyncUDPSocketAddress?

            socketQueueDo {
                result = self.cachedLocalAddress4Store
            }
            return result
        }
        set {
            socketQueueDo(async: false, {
                self.cachedLocalAddress4Store = newValue
            })
        }
    }

    public var cachedLocalAddress6: SwiftAsyncUDPSocketAddress? {
        get {
            var result: SwiftAsyncUDPSocketAddress?

            socketQueueDo {
                result = self.cachedLocalAddress6Store
            }
            return result
        }
        set {
            socketQueueDo(async: false, {
                self.cachedLocalAddress6Store = newValue
            })
        }
    }

    public var cachedConnectedAddress: SwiftAsyncUDPSocketAddress? {
        get {
            var result: SwiftAsyncUDPSocketAddress?

            socketQueueDo {
                result = self.cachedConnectedAddressStore
            }
            return result
        }
        set {
            socketQueueDo(async: false, {
                self.cachedConnectedAddressStore = newValue
            })
        }
    }

    public var isConnected: Bool {
        var result = false

        socketQueueDo {
            result = self.flags.contains(.didConnect)
        }
        return result
    }

    public var isClosed: Bool {
        var result = false

        socketQueueDo {
            result = !self.flags.contains(.didCreatSockets)
        }
        return result
    }
}
