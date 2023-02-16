//
//  SwiftAsyncSocket+LookUp.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2018/12/20.
//  Copyright © 2018 chouheiwa. All rights reserved.
//

import Foundation

extension SwiftAsyncSocket {

    func lookup(_ aStateIndex: Int,
                didSuccessWith dataType: SocketDataType) {
        assert(DispatchQueue.getSpecific(key: queueKey) != nil, "Must be dispatched on socketQueue")

        guard aStateIndex == stateIndex else {
            return
        }

        switch dataType {
        case .IPv4Data:
            guard isIPv4Enabled else {
                closeSocket(error: SwiftAsyncSocketError(msg:
                    "IPv4 has been disabled and DNS lookup found no IPv6 address."))
                return
            }
        case .IPv6Data:
            guard isIPv6Enabled else {
                closeSocket(error: SwiftAsyncSocketError(msg:
                    "IPv6 has been disabled and DNS lookup found no IPv4 address."))
                return
            }
        default:
            break
        }

        do {
            try connect(withSockData: dataType)
        } catch let error as SwiftAsyncSocketError {
            closeSocket(error: error)
        } catch {
            fatalError("\(error)")
        }
    }

    /// This method is called if the DNS lookup fails.
    /// This method is executed on the socketQueue.
    ///
    /// Since the DNS lookup executed synchronously on a global concurrent queue,
    /// the original connection request may have already been cancelled or timed-out by the time this method is invoked.
    /// The lookupIndex tells us whether the lookup is still valid or not.
    /// - Parameters:
    ///   - aStateIndex: stateIndex
    ///   - error: occurError
    func lookup(_ aStateIndex: Int,
                fail error: SwiftAsyncSocketError) {
        assert(DispatchQueue.getSpecific(key: queueKey) != nil, "Must be dispatched on socketQueue")

        guard aStateIndex == aStateIndex else {
            return
        }

        endConnectTimeout()
        closeSocket(error: error)
    }
}
