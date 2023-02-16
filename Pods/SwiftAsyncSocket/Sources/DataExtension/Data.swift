//
//  Data.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2018/12/18.
//  Copyright © 2018 chouheiwa. All rights reserved.
//

import Foundation

extension Data {
    func convert<DataType>(offset: Int = 0) -> UnsafePointer<DataType> {
        let buffer = self.withUnsafeBytes { buffer in
            return buffer
        }
        let unsafeBufferPointer = buffer.bindMemory(to: DataType.self)
        
        return unsafeBufferPointer.baseAddress! + offset
    }

    mutating func convertMutable<T>(offset: Int = 0) -> UnsafeMutablePointer<T> {
        
        let buffer = self.withUnsafeMutableBytes { buffer in
            return buffer.bindMemory(to: T.self)
        }
        
        return buffer.baseAddress! + offset
    }
}
