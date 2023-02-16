//
//  SwiftAsyncUDPSocket+Closing.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2019/1/15.
//  Copyright © 2019 chouheiwa. All rights reserved.
//

import Foundation

extension SwiftAsyncUDPSocket {
    func close(error: SwiftAsyncSocketError?) {
        assert(DispatchQueue.getSpecific(key: queueKey) != nil, "Must be dispatched on socketQueue")

        if currentSend != nil {
            endCurrentSend()
        }

        sendQueue.removeAll()

        closeSockets()

        flags = []

        guard flags.contains(.didCreatSockets) else {
            return
        }

        delegateQueue?.async {
            self.delegate?.updSocket(self, didCloseWith: error)
        }
    }

    func closeSockets() {
        closeSocket4()
        closeSocket6()

        flags.remove(.didCreatSockets)
    }

    func closeSocket4() {
        guard socket4FD != -1 else {
            return
        }

        send4Source?.cancel()
        receive4Source?.cancel()

        resumeSend4Source()
        resumeReceive4Source()

        send4Source = nil
        receive4Source = nil

        socket4FD = -1

        socket4FDBytesAvailable = 0

        flags.remove(.sock4CanAcceptBytes)

        cachedLocalAddress4 = nil
    }

    func closeSocket6() {
        guard socket6FD != -1 else {
            return
        }

        send6Source?.cancel()
        receive6Source?.cancel()

        resumeSend6Source()
        resumeReceive6Source()

        send6Source = nil
        receive6Source = nil

        socket6FD = -1

        socket6FDBytesAvailable = 0

        flags.remove(.sock6CanAcceptBytes)

        cachedLocalAddress6 = nil
    }
}
