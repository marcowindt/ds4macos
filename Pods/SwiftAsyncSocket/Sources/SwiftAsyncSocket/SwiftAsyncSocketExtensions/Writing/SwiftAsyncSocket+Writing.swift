//
//  SwiftAsyncSocket+Writing.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2018/12/17.
//  Copyright © 2018 chouheiwa. All rights reserved.
//

import Foundation

extension SwiftAsyncSocket {
    func maybeDequeueWrite() {
        assert(DispatchQueue.getSpecific(key: queueKey) != nil, "Must be dispatched on socketQueue")
        // If we're not currently processing a write AND we have an available write stream
        guard currentWrite == nil && (flags.contains(.connected)) else { return }

        if writeQueue.count > 0 {
            currentWrite = writeQueue.first
            writeQueue.removeFirst()

            if currentWrite as? SwiftAsyncSpecialPacket != nil {
                flags.insert(.startingWritingTLS)

                maybeStartTLS()
            } else if let currentWrite = currentWrite as? SwiftAsyncWritePacket {
                setupWriteTimer(timeOut: currentWrite.timeout)

                doWriteData()
            }
        } else if flags.contains(.disconnectAfterWrites) {
            if flags.contains(.disconnectAfterReads) {
                if readQueue.count == 0 && currentRead == nil {
                    closeSocket(error: nil)
                }
            } else {
                closeSocket(error: nil)
            }
        }
    }

    private func setupWriteTimer(timeOut: TimeInterval) {
        guard timeOut >= 0.0 else { return }

        writeTimer = DispatchSource.makeTimerSource(flags: [], queue: socketQueue)

        writeTimer?.setEventHandler(handler: { [weak self] in
            self?.doWriteTimeout()
        })

        writeTimer?.schedule(deadline: DispatchTime.now() + timeOut, repeating: .never, leeway: .nanoseconds(0))

        writeTimer?.resume()
    }

    private func doWriteTimeout() {
        flags.insert(.writePaused)

        if let delegateQueue = delegateQueue {
            guard let currentWrite = currentWrite as? SwiftAsyncWritePacket else { return }

            delegateQueue.async {
                var timeout = 0.0

                timeout = self.delegate?.socket(self,
                                                shouldTimeoutWriteWith: currentWrite.tag,
                                                elapsed: currentWrite.timeout,
                                                bytesDone: currentWrite.bytesDone) ?? 0.0

                self.socketQueue.async {
                    self.doWriteTimeout(extension: timeout)
                }
            }
        } else {
            self.doWriteTimeout(extension: 0.0)
        }
    }

    private func doWriteTimeout(extension timeout: TimeInterval) {
        guard currentWrite != nil else { assert(false, "Inviid Logic");fatalError("Inviid Logic") }

        guard let currentWrite = currentWrite as? SwiftAsyncWritePacket else { return }

        guard timeout > 0.0 else {
            closeSocket(error: SwiftAsyncSocketError.writeTimeoutError)
            return
        }

        currentWrite.timeout += timeout

        flags.remove(.writePaused)

        doWriteData()
    }

    func endCurrentWrite() {
        writeTimer?.cancel()
        writeTimer = nil

        currentWrite = nil
    }
}
