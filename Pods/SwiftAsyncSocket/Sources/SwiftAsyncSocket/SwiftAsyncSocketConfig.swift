//
//  SwiftAsyncSocketConfig.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2018/12/14.
//  Copyright © 2018 chouheiwa. All rights reserved.
//

import Foundation

struct SwiftAsyncSocketConfig: OptionSet, RawValueProtocol {
    var rawValue: Int

    typealias RawValue = Int

    init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

extension SwiftAsyncSocketConfig {
    static let IPv4Disabled = SwiftAsyncSocketConfig(rawValue: 1 << 0)
    static let IPv6Disabled = SwiftAsyncSocketConfig(rawValue: 1 << 1)
    static let preferIPv6 = SwiftAsyncSocketConfig(rawValue: 1 << 2)
    static let allowHalfDuplexConnection =
        SwiftAsyncSocketConfig(rawValue: 1 << 3) // If set, the socket will stay open even if the read stream closes
}
