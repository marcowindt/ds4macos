//
//  SwiftAsyncUdpSocketFlags.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2019/1/10.
//  Copyright © 2019 chouheiwa. All rights reserved.
//

import Foundation

struct SwiftAsyncUdpSocketFlags: OptionSet, RawValueProtocol {
    var rawValue: Int

    typealias RawValue = Int

    init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

extension SwiftAsyncUdpSocketFlags {
    static let didCreatSockets         = SwiftAsyncUdpSocketFlags(rawValue: 1 <<  0)
    static let didBind                 = SwiftAsyncUdpSocketFlags(rawValue: 1 <<  1)
    static let connecting              = SwiftAsyncUdpSocketFlags(rawValue: 1 <<  2)
    static let didConnect              = SwiftAsyncUdpSocketFlags(rawValue: 1 <<  3)
    static let receiveOnce             = SwiftAsyncUdpSocketFlags(rawValue: 1 <<  4)
    static let receiveContinuous       = SwiftAsyncUdpSocketFlags(rawValue: 1 <<  5)
    static let IPv4Deactivated         = SwiftAsyncUdpSocketFlags(rawValue: 1 <<  6)
    static let IPv6Deactivated         = SwiftAsyncUdpSocketFlags(rawValue: 1 <<  7)
    static let send4SourceSuspended    = SwiftAsyncUdpSocketFlags(rawValue: 1 <<  8)
    static let send6SourceSuspended    = SwiftAsyncUdpSocketFlags(rawValue: 1 <<  9)
    static let receive4SourceSuspended = SwiftAsyncUdpSocketFlags(rawValue: 1 << 10)
    static let receive6SourceSuspended = SwiftAsyncUdpSocketFlags(rawValue: 1 << 11)
    static let sock4CanAcceptBytes     = SwiftAsyncUdpSocketFlags(rawValue: 1 << 12)
    static let sock6CanAcceptBytes     = SwiftAsyncUdpSocketFlags(rawValue: 1 << 13)
    static let forbidSendReceive       = SwiftAsyncUdpSocketFlags(rawValue: 1 << 14)
    static let closeAfterSends         = SwiftAsyncUdpSocketFlags(rawValue: 1 << 15)
    static let flipFlop                = SwiftAsyncUdpSocketFlags(rawValue: 1 << 16)
    #if os(iOS)
    static let addedStreamListener     = SwiftAsyncUdpSocketFlags(rawValue: 1 << 17)
    #endif
}
