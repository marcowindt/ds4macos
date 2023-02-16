//
//  SwiftAsyncWritePacket.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2018/12/10.
//  Copyright © 2018 chouheiwa. All rights reserved.
//

import Foundation

class SwiftAsyncWritePacket: SwiftAsyncPacketProtocol {
    var buffer: Data
    var bytesDone: UInt = 0
    var tag: Int = 0
    var timeout: TimeInterval = 0

    init(buffer: Data, timeout: TimeInterval, tag: Int) {
        self.buffer = buffer
        self.timeout = timeout
        self.tag = tag
    }
}
