//
//  SwiftAsyncUDPSocket+Bind.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2019/1/16.
//  Copyright © 2019 chouheiwa. All rights reserved.
//

import Foundation

extension SwiftAsyncUDPSocket {
    func preBind() throws {
        try preOpen()

        guard !flags.contains(.didBind) else {
            throw SwiftAsyncSocketError.badConfig(msg:
                "Cannot bind a socket more than once.")
        }

        guard !flags.contains(.connecting) && !flags.contains(.didConnect) else {
            throw SwiftAsyncSocketError.badConfig(msg:
                "Cannot bind after connecting. If needed, bind first, then connect.")
        }

        guard isIPv4Enable || isIPv6Enable else {
            throw SwiftAsyncSocketError.badConfig(msg:
                "Both IPv4 and IPv6 have been disabled. Must enable at least one protocol first.")
        }
    }

    func bind(toData data: SocketDataType) throws {
        var dataType = data
        // All judge with change
        try dataType.change(IPv4Enable: isIPv4Enable, IPv6Enable: isIPv6Enable)

        let errorDone: () -> SwiftAsyncSocketError = {
            self.closeSockets()
            return SwiftAsyncSocketError.badParamError(
                "Error in bind() function")
        }

        switch dataType {
        case .IPv4Data(let data):
            if !self.flags.contains(.didCreatSockets) {
                try self.createSocket4()
            }
            guard Darwin.bind(self.socket4FD, data.convert(), socklen_t(data.count)) != -1 else {
                throw errorDone()
            }
            self.flags.insert(.IPv6Deactivated)
        case .IPv6Data(let data):
            if !self.flags.contains(.didCreatSockets) {
                try self.createSocket6()
            }
            guard Darwin.bind(self.socket6FD, data.convert(), socklen_t(data.count)) != -1 else {
                throw errorDone()
            }
            self.flags.insert(.IPv4Deactivated)
        case .bothData(let IPv4Data, let IPv6Data):
            if !self.flags.contains(.didCreatSockets) {
                try self.createSocket4()
                try self.createSocket6()
            }

            var result = Darwin.bind(self.socket4FD, IPv4Data.convert(), socklen_t(IPv4Data.count))

            guard result != -1 else {
                throw errorDone()
            }

            result = Darwin.bind(self.socket6FD, IPv6Data.convert(), socklen_t(IPv6Data.count))

            guard result != -1 else {
                throw errorDone()
            }
        }
    }
}
