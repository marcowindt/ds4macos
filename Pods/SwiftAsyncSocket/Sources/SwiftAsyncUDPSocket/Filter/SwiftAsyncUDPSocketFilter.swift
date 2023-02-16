//
//  SwiftAsyncUDPSocketFilter.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2019/1/11.
//  Copyright © 2019 chouheiwa. All rights reserved.
//

import Foundation

protocol SwiftAsyncUDPSocketFilter {
    associatedtype BlockType

    var filterBlock: BlockType {get}

    var queue: DispatchQueue {get}

    var async: Bool {get}
}
