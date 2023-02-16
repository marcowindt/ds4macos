//
//  SwiftAsyncSocketFlags.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2018/12/10.
//  Copyright © 2018 chouheiwa. All rights reserved.
//

import Foundation

struct SwiftAsyncSocketFlags: OptionSet, RawValueProtocol {
    var rawValue: Int

    typealias RawValue = Int

    init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

extension SwiftAsyncSocketFlags {
    static let started = SwiftAsyncSocketFlags(rawValue: 1 << 0)

    static let connected = SwiftAsyncSocketFlags(rawValue: 1 << 1)

    static let forbidReadWrites = SwiftAsyncSocketFlags(rawValue: 1 << 2)

    static let readsPaused = SwiftAsyncSocketFlags(rawValue: 1 << 3)

    static let writePaused = SwiftAsyncSocketFlags(rawValue: 1 << 4)

    static let disconnectAfterReads = SwiftAsyncSocketFlags(rawValue: 1 << 5)

    static let disconnectAfterWrites = SwiftAsyncSocketFlags(rawValue: 1 << 6)

    static let canAcceptBytes = SwiftAsyncSocketFlags(rawValue: 1 << 7)

    static let readSourceSuspended = SwiftAsyncSocketFlags(rawValue: 1 << 8)

    static let writeSourceSuspended = SwiftAsyncSocketFlags(rawValue: 1 << 9)

    static let queuedTLS = SwiftAsyncSocketFlags(rawValue: 1 << 10)

    static let startingReadTLS = SwiftAsyncSocketFlags(rawValue: 1 << 11)

    static let startingWritingTLS = SwiftAsyncSocketFlags(rawValue: 1 << 12)

    static let isSecure = SwiftAsyncSocketFlags(rawValue: 1 << 13)

    static let hasReadEOF = SwiftAsyncSocketFlags(rawValue: 1 << 14)

    static let readSteamClosed = SwiftAsyncSocketFlags(rawValue: 1 << 15)

    static let dealloc = SwiftAsyncSocketFlags(rawValue: 1 << 16)
}

#if os(iOS)
extension SwiftAsyncSocketFlags {
    static let addedStreamsToRunLoop = SwiftAsyncSocketFlags(rawValue: 1 << 17)

    static let isUsingCFStreamForTLS = SwiftAsyncSocketFlags(rawValue: 1 << 18)

    static let secureSocketHasBytesAvailable = SwiftAsyncSocketFlags(rawValue: 1 << 19)
}
#endif
