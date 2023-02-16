//
//  SwiftAsyncSocket+Utilities.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2018/12/17.
//  Copyright © 2018 chouheiwa. All rights reserved.
//

import Foundation

// MARK: - Utilities
extension SwiftAsyncSocket {
    func setupReadAndWritesSources(forNewlyConnectedSocket socketFD: Int32) {
        readSource = DispatchSource.makeReadSource(fileDescriptor: socketFD, queue: socketQueue)
        writeSource = DispatchSource.makeWriteSource(fileDescriptor: socketFD, queue: socketQueue)

        readSource?.setEventHandler(handler: { [weak self] in
            guard let `self` = self else { return }

            self.socketFDBytesAvailable = self.readSource?.data ?? 0

            if self.socketFDBytesAvailable > 0 {
                self.doReadData()
            } else { self.doReadEOF() }
        })

        writeSource?.setEventHandler(handler: { [weak self] in
            guard let `self` = self else { return }

            self.flags.insert(.canAcceptBytes)

            self.doWriteData()
        })

        var socketFDRefCount = 2

        let handler: @convention(block) () -> Void = {
            socketFDRefCount -= 1
            guard socketFDRefCount == 0 else { return }

            Darwin.close(socketFD)
        }

        readSource?.setCancelHandler(handler: handler)

        writeSource?.setCancelHandler(handler: handler)

        // We will not be able to read until data arrives.
        // But we should be able to write immediately.

        socketFDBytesAvailable = 0
        flags.remove(.readSourceSuspended)

        readSource?.resume()

        flags.insert([.canAcceptBytes, .writeSourceSuspended])
    }

    func suspendReadSource() {
        guard !flags.contains(.readSourceSuspended) else { return }

        // Need Log
        readSource?.suspend()
        flags.insert(.readSourceSuspended)
    }

    func resumeReadSource() {
        guard flags.contains(.readSourceSuspended) else { return }
        // Need Log
        readSource?.resume()
        flags.remove(.readSourceSuspended)
    }

    func suspendWriteSource() {
        guard !flags.contains(.writeSourceSuspended) else { return }

        // Need Log

        writeSource?.suspend()
        flags.insert(.writeSourceSuspended)
    }

    func resumeWriteSource() {
        guard flags.contains(.writeSourceSuspended) else { return }

        // Need Log

        writeSource?.resume()
        flags.remove(.writeSourceSuspended)
    }
}
