//
//  SwiftAsyncUDPSpecialPacket.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2019/1/10.
//  Copyright © 2019 chouheiwa. All rights reserved.
//

import Foundation

class SwiftAsyncUDPSpecialPacket: SwiftAsyncUDPPacket {
    var resolveInProgress: Bool = false

    var resolvedAddresses: SocketDataType?

    var resolvedError: SwiftAsyncSocketError?
}
