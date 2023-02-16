//
//  SwiftAsyncUDPSocket+Multicast.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2019/1/18.
//  Copyright © 2019 chouheiwa. All rights reserved.
//

import Foundation

extension SwiftAsyncUDPSocket {

    /// Join multicast group.
    ///
    /// - Parameters:
    ///   - group: IP address (eg @"225.228.0.1").
    ///   - interface: a name (e.g. "en1" or "lo0") or the corresponding IP address (e.g. "192.168.4.35")
    /// - Throws: error
    public func join(multiscast group: String,
                     interface: String? = nil) throws {
        try performWithQueue(requestType: .join, group: group, interface: interface)
    }
    /// Leave multicast group.
    ///
    /// - Parameters:
    ///   - group: IP address (eg @"225.228.0.1").
    ///   - interface: a name (e.g. "en1" or "lo0") or the corresponding IP address (e.g. "192.168.4.35")
    /// - Throws: error
    public func leave(multiscast group: String,
                      interface: String? = nil) throws {
        try performWithQueue(requestType: .leave, group: group, interface: interface)
    }
}
