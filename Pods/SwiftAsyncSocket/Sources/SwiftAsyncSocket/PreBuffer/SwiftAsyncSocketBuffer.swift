//
//  SwiftAsyncSocketBuffer.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2018/12/6.
//  Copyright © 2018 chouheiwa. All rights reserved.
//

import Foundation

public protocol SwiftAsyncSocketBuffer {
    var preBuffer: UnsafeMutablePointer<UInt8> {get}
    var preBufferSize: size_t {get}
    var readPointer: UnsafeMutablePointer<UInt8> {get}
    var writePointer: UnsafeMutablePointer<UInt8> {get}

    var availableSpace: size_t { get }

    var availableBytes: size_t { get }
    /// 确保缓存区足够大(在写入前调用)
    ///
    /// - Parameter capacity: 将要写入的容量
    func ensureCapacityForWrite(capacity: size_t)

    /// 已经读取过字节数
    ///
    /// - Parameter readBytes: 字节长度
    func didRead(_ readBytes: size_t)

    /// 确认已经写入过多少字节
    ///
    /// - Parameter writeBytes: 写入字节长度
    func didWrite(_ writeBytes: size_t)

    /// 重置所有属性
    func reset()
}
