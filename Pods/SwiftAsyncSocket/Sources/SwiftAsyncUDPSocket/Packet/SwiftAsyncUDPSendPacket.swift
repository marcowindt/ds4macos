//
//  SwiftAsyncUDPSendPacket.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2019/1/10.
//  Copyright © 2019 chouheiwa. All rights reserved.
//

import Foundation

class SwiftAsyncUDPSendPacket: SwiftAsyncUDPPacket {
    let buffer: Data

    let timeout: TimeInterval

    var tag: Int

    var resolveInProgress: Bool = false

    var filterInProgress: Bool = false

    var resolvedAddresses: SocketDataType?

    var resolvedError: SwiftAsyncSocketError?

    var address: SwiftAsyncUDPSocketAddress?

    init(buffer: Data, timeout: TimeInterval, tag: Int) {
        self.buffer = buffer
        self.timeout = timeout
        self.tag = tag
    }

    final class func == (left: SwiftAsyncUDPSendPacket, right: SwiftAsyncUDPPacket?) -> Bool {
        guard let right = right as? SwiftAsyncUDPSendPacket else {
            return false
        }

        return left === right
    }
}
