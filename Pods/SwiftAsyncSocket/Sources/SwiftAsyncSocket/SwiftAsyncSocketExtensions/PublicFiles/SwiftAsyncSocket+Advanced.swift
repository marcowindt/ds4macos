//
//  SwiftAsyncSocket+Advanced.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2019/1/2.
//  Copyright © 2019 chouheiwa. All rights reserved.
//

import Foundation

// MARK: - Advanced
extension SwiftAsyncSocket {
    /**
     *  The same question maybe in the SwiftAsyncSocket is that the deadlock
     */
    public func markSocketQueue(newSocketQueue: DispatchQueue) {
        newSocketQueue.setSpecific(key: queueKey, value: self)
    }

    public func unmarkSocketQueue(oldSocketQueue: DispatchQueue) {
        oldSocketQueue.setSpecific(key: queueKey, value: nil)
    }

    /// You can use this function to make a job done in the socketQueue
    ///
    /// - Parameters:
    ///   - sync: is use sync
    ///   - block: done job
    public func socketQueueDo(sync: Bool = true, _ block:@escaping (() -> Void)) {
        if DispatchQueue.getSpecific(key: queueKey) != nil {
            block()
        } else {
            if sync {
                socketQueue.sync(execute: block)
            } else {
                socketQueue.async(execute: block)
            }
        }
    }
}
