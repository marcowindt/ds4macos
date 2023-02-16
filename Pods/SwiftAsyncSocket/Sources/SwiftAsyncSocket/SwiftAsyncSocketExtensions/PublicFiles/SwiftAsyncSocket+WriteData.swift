//
//  SwiftAsyncSocket+WriteData.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2019/1/2.
//  Copyright © 2019 chouheiwa. All rights reserved.
//

import Foundation
// MARK: - WriteData
extension SwiftAsyncSocket {
    /// Writes data to the socket, and calls the delegate when finished.
    /// If you pass in nil or zero-length data,
    /// this method does nothing and the delegate will not be called.
    ///
    /// - Parameters:
    ///   - data: data
    ///   - timeOut: nagetive time to make never time out
    ///   - tag: tag
    public func write(data: Data,
                      timeOut: TimeInterval,
                      tag: Int) {
        guard data.count > 0 else {return}

        let packet = SwiftAsyncWritePacket(buffer: data,
                                           timeout: timeOut,
                                           tag: tag)

        socketQueueDo(sync: false) {
            guard self.flags.contains(.started) && !self.flags.contains(.forbidReadWrites) else {
                return
            }
            self.writeQueue.append(packet)
            self.maybeDequeueWrite()
        }
    }

    /// This method will return the progress of current read
    /// It will return nil if there was no current write
    ///
    /// - Returns: ReadProgress
    public func progressOfCurrentWrite() -> ReadWriteProgress? {
        var readProgress: ReadWriteProgress?

        socketQueueDo {
            guard let currentWrite = self.currentWrite as? SwiftAsyncWritePacket else {
                return
            }

            // It's only possible to know the progress of our read if we're reading to a certain length.
            // If we're reading to data, we of course have no idea when the data will arrive.
            // If we're reading to timeout, then we have no idea when the next chunk of data will arrive.

            let total = currentWrite.buffer.count

            let done = currentWrite.bytesDone

            readProgress = ReadWriteProgress(tag: currentWrite.tag,
                                             bytesDone: currentWrite.bytesDone,
                                             total: UInt(total),
                                             progress: total > 0 ? Float(done) / Float(total) : 1.0)
        }

        return readProgress
    }
}
