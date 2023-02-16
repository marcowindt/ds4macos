//
//  SwiftAsyncSocket+ClassUtilities.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2018/12/20.
//  Copyright © 2018 chouheiwa. All rights reserved.
//

import Foundation

extension SwiftAsyncSocket {
    public class var CRLFData: Data {
        var list: [UInt8] = [0x0D, 0x0A]

        return Data(bytes: &list, count: 2)
    }

    public class var CRData: Data {
        var list: [UInt8] = [0x0D]

        return Data(bytes: &list, count: 1)
    }

    public class var LFData: Data {
        var list: [UInt8] = [0x0A]

        return Data(bytes: &list, count: 1)
    }

    public class var zeroData: Data {
        var list: [UInt8] = [0x00]

        return Data(bytes: &list, count: 1)
    }

}
