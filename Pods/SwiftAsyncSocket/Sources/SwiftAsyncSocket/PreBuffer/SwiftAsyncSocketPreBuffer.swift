//
//  SwiftAsyncSocketPreBuffer.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2018/12/5.
//  Copyright © 2018 chouheiwa. All rights reserved.
//

import Foundation

class SwiftAsyncSocketPreBuffer: SwiftAsyncSocketBuffer {
    /// 预加载缓存区
    var preBuffer: UnsafeMutablePointer<UInt8>
    /// 预加载缓存区大小
    var preBufferSize: size_t = 0
    /// 读取指针
    var readPointer: UnsafeMutablePointer<UInt8>
    /// 写入指针
    var writePointer: UnsafeMutablePointer<UInt8>

    /// 根据容量初始化缓存区
    ///
    /// - Parameter capacity: 容量
    init(capacity: size_t) {
        preBuffer = malloc(capacity).assumingMemoryBound(to: UInt8.self)

        preBufferSize = capacity

        memset(preBuffer, 0, capacity)

        readPointer = preBuffer
        writePointer = preBuffer
    }

    deinit {
        free(preBuffer)
    }
}

extension SwiftAsyncSocketPreBuffer {

    /// 剩余可用容量
    var availableSpace: size_t {
        return preBufferSize - (writePointer - readPointer)
    }

    var availableBytes: size_t {
        return writePointer - readPointer
    }

    /// 确保缓存区足够大(在写入前调用)
    ///
    /// - Parameter capacity: 将要写入的容量
    func ensureCapacityForWrite(capacity: size_t) {
        guard capacity > availableSpace else { return }

        let additionalBytes = capacity - availableSpace

        let newPreBufferSize = preBufferSize + additionalBytes

        let newBuffer = realloc(preBuffer, newPreBufferSize).assumingMemoryBound(to: UInt8.self)

        let readPointerOffset = readPointer - preBuffer

        let writePointerOffset = writePointer - preBuffer

        preBuffer = newBuffer

        preBufferSize = newPreBufferSize

        readPointer = preBuffer + readPointerOffset

        writePointer = preBuffer + writePointerOffset
    }

    func didRead(_ readBytes: size_t) {
        readPointer += readBytes

        guard readPointer == writePointer else { return }

        reset()
    }

    func didWrite(_ writeBytes: size_t) {
        guard writeBytes <= availableSpace else { fatalError("Write Data Failed,capacity is not enougth") }

        writePointer += writeBytes
    }

    func reset() {
        readPointer = preBuffer
        writePointer = preBuffer
    }
}
