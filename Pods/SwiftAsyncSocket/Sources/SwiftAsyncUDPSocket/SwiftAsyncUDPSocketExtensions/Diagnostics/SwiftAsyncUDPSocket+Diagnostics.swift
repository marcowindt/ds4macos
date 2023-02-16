//
//  SwiftAsyncUDPSocket+Diagnostics.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2019/1/16.
//  Copyright © 2019 chouheiwa. All rights reserved.
//

import Foundation

extension SwiftAsyncUDPSocket {
    func maybeUpdatedCachedLocalAddress4Info() {
        assert(DispatchQueue.getSpecific(key: queueKey) != nil)

        guard cachedLocalAddress4 == nil
            && flags.contains(.didBind) && socket4FD != -1
            else {
            return
        }

        guard let socket = sockaddr_in.getLocalSocketFD(socket4FD) else {
            return
        }

        cachedLocalAddress4 = SwiftAsyncUDPSocketAddress(socket4: socket)
    }

    func maybeUpdatedCachedLocalAddress6Info() {
        assert(DispatchQueue.getSpecific(key: queueKey) != nil)

        guard cachedLocalAddress6 == nil
            && flags.contains(.didBind) && socket6FD != -1
            else {
                return
        }

        guard let socket = sockaddr_in6.getLocalSocketFD(socket6FD) else {
            return
        }

        cachedLocalAddress6 = SwiftAsyncUDPSocketAddress(socket6: socket)
    }

    func maybeUpdateCachedConnectedAddressInfo() {
        assert(DispatchQueue.getSpecific(key: queueKey) != nil)

        guard cachedConnectedAddress == nil
            && flags.contains(.didConnect)
            else {
                return
        }

        if socket4FD != -1 {
            guard let socket = sockaddr_in.getPeerSocketFD(socket4FD) else {
                return
            }

            cachedConnectedAddress = SwiftAsyncUDPSocketAddress(socket4: socket)

        } else if socket6FD != -1 {
            guard let socket = sockaddr_in6.getPeerSocketFD(socket4FD) else {
                return
            }

            cachedConnectedAddress = SwiftAsyncUDPSocketAddress(socket6: socket)
        }
    }
}
