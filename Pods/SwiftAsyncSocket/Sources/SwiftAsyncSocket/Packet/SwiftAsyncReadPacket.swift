//
//  SwitAsyncReadPacket.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2018/12/5.
//  Copyright © 2018 chouheiwa. All rights reserved.
//

import Foundation

protocol SwiftAsyncPacketProtocol: AnyObject {}

/// This struct is for socket read preBuffer
/// 这个结构体是用来做读取加载区 (有可能配合着预加载区使用)
public class SwiftAsyncReadPacket: SwiftAsyncPacketProtocol {
    /// 读取缓冲区
    public var buffer: Data
    /// 起始偏移量
    public var startOffset: UInt = 0
    /// 已经完成的字节量
    public var bytesDone: UInt = 0
    /// 最大长度
    public var maxLength: UInt?
    /// 获取超时时间
    public var timeout: TimeInterval = 0.0
    /// 给定读取长度
    public var readLength: UInt?
    /// 结束特征码
    public let terminatorData: Data?
    /// 缓存所有者
    public var bufferOwner: Bool = true
    /// 原始缓存区长度
    public var originBufferLength: UInt = 0
    /// 标志
    public var tag: Int

    public init(buffer: Data?,
                startOffset: UInt = 0,
                maxLength: UInt? = nil,
                timeout: TimeInterval = 0.0,
                readLength: UInt? = nil,
                terminatorData: Data? = nil,
                tag: Int) {

        self.bytesDone = 0
        self.maxLength = maxLength
        self.timeout = timeout
        self.readLength = readLength
        self.terminatorData = terminatorData

        if let buffer = buffer {
            self.buffer = buffer
            self.bufferOwner = false
            self.startOffset = startOffset
            self.originBufferLength = UInt(buffer.count)
        } else {
            if let readLength = readLength {
                self.buffer = Data(count: Int(readLength))
            } else {
                self.buffer = Data(count: 0)
            }

            self.startOffset = 0
            self.bufferOwner = true
            self.originBufferLength = 0
        }

        self.tag = tag
    }
}

// MARK: - 增大空间
extension SwiftAsyncReadPacket {
    private var availableBufferSpace: UInt {
        let buffSize = buffer.count

        let buffUsed = startOffset + bytesDone

        let buffSpace = buffSize - Int(buffUsed)

        return UInt(buffSpace)
    }

    /// 扩充读写组缓存区长度
    ///
    /// - Parameter additionalDataOfLength: 需要的额外长度
    public func ensureCapacity(for additionalDataOfLength: UInt) {
        guard additionalDataOfLength > availableBufferSpace else {return}
        buffer.count =  Int(additionalDataOfLength + startOffset + bytesDone)
    }
    /// 当我们不知道有可能从socket连接中获得多少数据的时候我们需要使用这个方法
    ///
    /// - Parameter defaultValue: 给定默认数值
    /// - Returns: (默认长度(如果默认长度没有达到最大值同时我们给定没有读取长度),是否需要准备预读取指针)
    public func optimalReadLength(with defaultValue: UInt) -> (UInt, Bool) {
        if let readLength = readLength, (readLength > 0) { return (readLength - bytesDone, false) }
        var result = defaultValue

        if let maxLength = maxLength, (maxLength > 0) {result = min(defaultValue, maxLength - bytesDone)}

        return (result, availableBufferSpace < result)
    }
}

// MARK: - 不给定结束特征码时可用的方法
extension SwiftAsyncReadPacket {
    /// 这个方法只能在没有给定结束数据的时候调用
    /// 可以在不超过最大长度或读取长度的情况下返回数据的长度
    ///
    /// - Parameter bytesAvailable: socket 可以返回的限制 (必须大于0)
    /// - Returns: 数据长度
    public func readLength(for bytesAvailable: UInt) -> UInt {
        guard terminatorData == nil, (bytesAvailable > 0) else {
            assert(false, "Terminator Data is not nil, or bytesAvailable is zero")
            return 0
        }

        if let readLength = readLength, (readLength > 0) {
            // No need to avoid resizing the buffer.
            // If the user provided their own buffer,
            // and told us to read a certain length of data that exceeds the size of the buffer,
            // then it is clear that our code will resize the buffer during the read operation.
            //
            // This method does not actually do any resizing.
            // The resizing will happen elsewhere if needed.

            // 如果给定读取数据的大小的时候
            // 在这段代码中我们无需调整缓存区的大小
            // 如果用户提供了缓存区，并且告诉我们一个确定的超出缓存大小的数值
            // 则我们的程序可以很轻易的在读取操作的时候重新分配缓存区大小
            //
            // 这个方法不会立刻调整缓存的大小
            // 在其他的方法里，如果有必要的话，将会调整缓存大小

            return min(bytesAvailable, readLength - bytesDone)
        }
        // 读取所有可能字节
        if let maxLength = maxLength, (maxLength > 0) {
            return min((maxLength - bytesDone), bytesAvailable)
        }

        return bytesAvailable
    }
}

extension SwiftAsyncReadPacket {
    /// 调用这个方法的时候，需要预先设置结束二进制码。将会在不超过设置最大长度的情况下，返回数据的长度
    /// 原作者在此有另一个指针参数用以标志是否需要预缓存区，他的理由是NSMutableData无法更改自己大小，
    /// 但是swift中已经可以通过设置count来进行Data大小的切换，故此代码不在设置预缓存区
    /// 但是预缓存相关类也已经写入当前文件中，也可以随时切换
    /// - Parameter bytesAvailable: 给定的预估字符串含量，会被考虑在计算过程中
    /// - Returns: 返回读取字节长度
    public func readLengthForTerminator(hint bytesAvailable: UInt) -> (UInt, Bool) {
        guard terminatorData != nil, bytesAvailable > 0 else {
            assert(false, "Terminator Data is nil, or bytesAvailable is zero")
            return (0, false)
        }

        var result = bytesAvailable

        if let maxLength = maxLength, (maxLength > 0) {
            result = min(bytesAvailable, maxLength - bytesDone)
        }

        let buffSize = buffer.count

        let buffUsed = startOffset + bytesDone

        let shouldPreBufferPtr = (buffSize - Int(buffUsed)) < result

        return (result, shouldPreBufferPtr)
    }

    public func readLengthForTerminator(with buffers: SwiftAsyncSocketBuffer) -> (UInt, Bool) {
        // We know that the terminator, as a whole, doesn't exist in our own buffer.
        // But it is possible that a _portion_ of it exists in our buffer.
        // So we're going to look for the terminator starting with a portion of our own buffer.
        //
        // Example:
        //
        // term length      = 3 bytes
        // bytesDone        = 5 bytes
        // preBuffer length = 5 bytes
        //
        // If we append the preBuffer to our buffer,
        // it would look like this:
        //
        // ---------------------
        // |B|B|B|B|B|P|P|P|P|P|
        // ---------------------
        //
        // So we start our search here:
        //
        // ---------------------
        // |B|B|B|B|B|P|P|P|P|P|
        // -------^-^-^---------
        //
        // And move forwards...
        //
        // ---------------------
        // |B|B|B|B|B|P|P|P|P|P|
        // ---------^-^-^-------
        //
        // Until we find the terminator or reach the end.
        //
        // ---------------------
        // |B|B|B|B|B|P|P|P|P|P|
        // ---------------^-^-^-

        // 当执行到这个方法的时候我们已经知道了，终止特征数据作为一个整体，已经不存在于我们的缓存数据中了。
        // 但是它可能会部分存在于我们的缓存区中
        // 因此我们应该在我们的缓存区继续寻找结束符的部分
        //
        // 例子(就不翻译了，这个应该不是很难理解)

        guard let terminatorData = terminatorData, (terminatorData.count > 0) else {
            assert(false, "This method does not apply to non-term reads")
            return (0, false)}
        assert(buffers.availableBytes > 0, "Invoked with empty pre buffer!")

        var found = false
        let termLength = terminatorData.count
        let preBufferLength = buffers.availableBytes
        guard Int(bytesDone) + preBufferLength >= termLength else {
            return (UInt(preBufferLength), false)}

        var maxPreBufferLength = preBufferLength

        if let maxLength = maxLength, (maxLength > 0) {
            maxPreBufferLength = min(preBufferLength, (Int(maxLength) - Int(bytesDone)))
        }

        var bufLen = min(bytesDone, (UInt(termLength - 1)))

        var buf: UnsafePointer<UInt8> = buffer.convert(offset: Int(startOffset + bytesDone))

        var pre = buffers.readPointer

        var preLen = termLength - Int(bufLen)

        let loopCount = Int(bufLen) + maxPreBufferLength - termLength + 1

        var result = maxPreBufferLength

        for _ in 0..<loopCount {
            if bufLen > 0 {
                var data = Data(bytes: buf, count: Int(bufLen))
                
                data += Data(bytes: pre, count: preLen)

                if data == terminatorData {
                    result = preLen + termLength
                    found = true
                    break
                }

                buf += 1
                bufLen -= 1
                preLen += 1
            } else {
                let targetData = Data(bytes: pre, count: termLength)
                if targetData == terminatorData {
                    let preOffset = pre - buffers.readPointer

                    result = preOffset + termLength
                    found = true
                    break
                }

                pre += 1
            }
        }

        return (UInt(result), found)
    }

    /// 这个方法是为了设置过终止二进制码准备的，使用结束符扫描缓存区
    /// 这个方法会先假定结束符没有被完全扫描
    ///
    /// - Parameter numberOfBytes: 扫描缓存区多少个字节
    /// - Returns: 返回距离给定查找字节的距离，否则返回-1,如果返回值为0，则说明，在最后的位置找到的
    public func searchForTerminator(afterPrebuffering numberOfBytes: ssize_t) -> Int {
        guard let terminatorData = terminatorData else {
            assert(false, "This method does not apply to non-term reads")
            return -1
        }

        let buff: UnsafePointer<UInt8> = buffer.convert()

        let buffLength = Int(bytesDone) + numberOfBytes

        let termLength: Int = terminatorData.count

        var count = ((buffLength - numberOfBytes) >= termLength) ? (buffLength - numberOfBytes - termLength + 1) : 0

        while count + termLength <= buffLength {
            let subBuffer: UnsafePointer<UInt8> = buff + Int(startOffset) + count
            let compare = Data(bytes: subBuffer, count: termLength)
            
            if compare == terminatorData {
                return buffLength - (count + termLength)
            }

            count += 1
        }

        return -1
    }
}
