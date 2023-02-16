//
//  SwiftAsyncUDPPacketProtocol.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2019/1/10.
//  Copyright © 2019 chouheiwa. All rights reserved.
//

import Foundation

protocol SwiftAsyncUDPPacket {
    var resolveInProgress: Bool {get set}

    var resolvedAddresses: SocketDataType? {get set}

    var resolvedError: SwiftAsyncSocketError? {get set}
}
