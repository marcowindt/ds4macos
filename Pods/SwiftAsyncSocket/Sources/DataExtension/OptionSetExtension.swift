//
//  OptionSetExtension.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2018/12/12.
//  Copyright © 2018 chouheiwa. All rights reserved.
//

import Foundation

protocol RawValueProtocol {
    var rawValue: Int {get set}
}

extension OptionSet where Self.RawValue == Int, Self: RawValueProtocol {
    mutating func formUnion(_ other: Self) {
        rawValue |= other.rawValue
    }

    mutating func formIntersection(_ other: Self) {
        rawValue &= other.rawValue
    }

    mutating func formSymmetricDifference(_ other: Self) {
        rawValue ^= other.rawValue
    }
}
