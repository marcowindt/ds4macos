//
//  SwiftAsyncUdpSocketConfig.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2019/1/10.
//  Copyright © 2019 chouheiwa. All rights reserved.
//

import Foundation

struct SwiftAsyncUdpSocketConfig: OptionSet, RawValueProtocol {
    var rawValue: Int

    typealias RawValue = Int

    init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

extension SwiftAsyncUdpSocketConfig {
    static let IPv4Disabled = SwiftAsyncUdpSocketConfig(rawValue: 1 << 0)
    static let IPv6Disabled = SwiftAsyncUdpSocketConfig(rawValue: 1 << 1)
    static let preferIPv4   = SwiftAsyncUdpSocketConfig(rawValue: 1 << 2)
    static let preferIPv6   = SwiftAsyncUdpSocketConfig(rawValue: 1 << 3)
}
