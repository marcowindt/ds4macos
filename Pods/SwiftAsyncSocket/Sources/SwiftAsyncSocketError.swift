//
//  SwiftAsyncSocketError.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2018/12/10.
//  Copyright © 2018 chouheiwa. All rights reserved.
//

import Foundation

enum SwiftAsyncSocketAssertError: CustomStringConvertible {
    private struct ErrorKeys {
        static let queueLevel = "The given socketQueue parameter must not be a concurrent queue."

        static let socketQueueAction = "Must be dispatched on socketQueue"

        static let stream = "Read/Write stream is null"

        static let refError = "Ref can not be other class"

        static let classError = "Invalid value for. Value must be of type "

        static let stringDataError = "Can not convert string to data"

        static let castBufferError = "Buffer can not be cast because baseAddress is nil"

        static let secureError = "Cannot flush ssl buffers on non-secure socket"

        private init() {}
    }
    case queueLevel

    case socketQueueAction

    case stream

    case refError

    case classError(_ className:String)

    case stringDataError

    case castBufferError

    case secureError

    var description: String {
        switch self {
        case .queueLevel:
            return ErrorKeys.queueLevel
        case .socketQueueAction:
            return ErrorKeys.socketQueueAction
        case .stream:
            return ErrorKeys.stream
        case .refError:
            return ErrorKeys.refError
        case .classError(let msg):
            return "\(ErrorKeys.classError)\(msg)."
        case .stringDataError:
            return ErrorKeys.stringDataError
        case .castBufferError:
            return ErrorKeys.castBufferError
        case .secureError:
            return ErrorKeys.secureError
        }
    }
}

public enum SwiftAsyncSocketError: Swift.Error {
    case readMaxedOut

    case badConfig(msg: String)

    case badParamError(_ reason: String)

    #if os(iOS)

    case cfError(error: CFError)

    #endif

    case sslError(code: OSStatus)

    case gaiError(code: Int32)

    case connectionClosedError

    case connectTimeoutError

    case writeTimeoutError

    case errno(code: Int32, reason: String)

    case other(userInfo: [String: Any]?)

    init(msg: String?) {
        self = .other(userInfo: ["ErrorDetail": msg ?? "No description"])
    }
}

extension SwiftAsyncSocketError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .readMaxedOut:
            return "Error Domain:\"SwiftAsyncSocketErrorDomain\"" +
            " Error kind: ReadMaxedOut Description: \"Read operation reached set maximum length\""
        case .badConfig(let msg):
            return "Error Domain:\"SwiftAsyncSocketErrorDomain\" Error kind: badConfig Description: \(msg)"
        case .badParamError(let param):
            return "Error Domain:\"SwiftAsyncSocketErrorDomain\" Error kind: badParamError Description: \(param)"
        #if os(iOS)
        case .cfError(let error):
            return "\(error)"
        #endif
        case .sslError(let status):
            return "Error Domain:\"SwiftAsyncSocketErrorDomain\"" +
                " Error kind: SSLError Error code:\(status)" +
            " Description: \"Error code definition can be found in Apple's SecureTransport.h\""
        case .gaiError(let code):
            return "Error Domain:\"SwiftAsyncSocketErrorDomain\"" +
                " Error kind: gaiError Error code:\(code)" +
            " Description: \(String(cString: gai_strerror(code)))"
        case .connectionClosedError:
            return "Error Domain:\"SwiftAsyncSocketErrorDomain\"" +
            " Error kind: ConnectionClosedError Description: \"Socket closed by remote peer\""
        case .connectTimeoutError:
            return "Error Domain:\"SwiftAsyncSocketErrorDomain\"" +
            " Error kind: ConnectTimeoutError Description: \"Connect operation timed out\""
        case .writeTimeoutError:
            return "Error Domain:\"SwiftAsyncSocketErrorDomain\"" +
            " Error kind: WriteTimeoutError Description: \"Write operation timed out\""

        case .errno(let code, let reason):
            return "Error Domain:\"SwiftAsyncSocketErrorDomain\"" +
            " Error kind: Errno.Error Code: \(code) Description: \(reason)"
        case .other(let userInfo):
            let userInfoValue = userInfo ?? [:]

            return "Error Domain:\"SwiftAsyncSocketErrorDomain\" Error kind: other UserInfo:\(userInfoValue)"
        }
    }
}
