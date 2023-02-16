//
//  SwiftAsyncSpecialPacket.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2018/12/10.
//  Copyright © 2018 chouheiwa. All rights reserved.
//

import Foundation

class SwiftAsyncSpecialPacket: SwiftAsyncPacketProtocol {
    var tlsSettings: SwiftAsyncSocket.TLSSettings

    init(_ tlsSettings: SwiftAsyncSocket.TLSSettings) {
        self.tlsSettings = tlsSettings
    }
}
