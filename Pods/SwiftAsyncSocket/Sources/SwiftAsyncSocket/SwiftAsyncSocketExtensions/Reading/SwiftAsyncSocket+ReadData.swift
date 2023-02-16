//
//  SwiftAsyncSocket+ReadData.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2019/1/2.
//  Copyright © 2019 chouheiwa. All rights reserved.
//

import Foundation

extension SwiftAsyncSocket {
    public func readData(timeOut: TimeInterval,
                         buffer: Data? = nil,
                         bufferOffSet offSet: UInt = 0,
                         maxLength: UInt? = nil,
                         tag: Int) {
        guard buffer?.count ?? 0 >= offSet else {
            return
        }

        let packet = SwiftAsyncReadPacket(buffer: buffer,
                                          startOffset: offSet,
                                          maxLength: maxLength,
                                          timeout: timeOut,
                                          tag: tag)

        socketQueueDo(sync: false) {
            guard self.flags.contains(.started) && !self.flags.contains(.forbidReadWrites) else {
                return
            }

            self.readQueue.append(packet)
            self.maybeDequeueRead()
        }
    }

    public func readData(toLength length: UInt,
                         timeOut: TimeInterval,
                         buffer: Data? = nil,
                         bufferOffSet offSet: UInt = 0,
                         tag: Int) {
        guard length != 0 && buffer?.count ?? 0 >= offSet else {
            return
        }
        let packet = SwiftAsyncReadPacket(buffer: buffer,
                                          startOffset: offSet,
                                          timeout: timeOut,
                                          readLength: length,
                                          tag: tag)

        socketQueueDo(sync: false) {
            guard self.flags.contains(.started) && !self.flags.contains(.forbidReadWrites) else {
                return
            }

            self.readQueue.append(packet)
            self.maybeDequeueRead()
        }
    }

    public func readData(toData data: Data,
                         timeOut: TimeInterval,
                         buffer: Data? = nil,
                         bufferOffSet offset: UInt = 0,
                         maxLength: UInt = 0,
                         tag: Int) {
        guard data.count > 0 else { return }
        guard buffer?.count ?? 0 >= offset else {
            return
        }
        guard maxLength == 0 || (maxLength > data.count) else {
            return
        }

        let packet = SwiftAsyncReadPacket(buffer: buffer,
                                          startOffset: offset,
                                          maxLength: maxLength,
                                          timeout: timeOut,
                                          terminatorData: data,
                                          tag: tag)

        socketQueueDo(sync: false) {
            guard self.flags.contains(.started) && !self.flags.contains(.forbidReadWrites) else {
                return
            }

            self.readQueue.append(packet)
            self.maybeDequeueRead()
        }
    }

    /// Result of current read|Write
    public struct ReadWriteProgress {
        public let tag: Int
        public let bytesDone: UInt
        public let total: UInt
        public let progress: Float
    }

    /// Return progress of currentRead, return zero if no currentRead or currentRead is
    ///
    /// - Returns: ReadProgress
    public func progressOfCurrentRead() -> ReadWriteProgress? {
        var readProgress: ReadWriteProgress?

        socketQueueDo {
            guard let currentRead = self.currentRead as? SwiftAsyncReadPacket else {
                return
            }

            // It's only possible to know the progress of our read if we're reading to a certain length.
            // If we're reading to data, we of course have no idea when the data will arrive.
            // If we're reading to timeout, then we have no idea when the next chunk of data will arrive.

            let total = currentRead.readLength ?? 0

            let done = currentRead.bytesDone

            readProgress = ReadWriteProgress(tag: currentRead.tag,
                                        bytesDone: currentRead.bytesDone,
                                        total: total,
                                        progress: total > 0 ? Float(done) / Float(total) : 1.0)
        }

        return readProgress
    }
}
