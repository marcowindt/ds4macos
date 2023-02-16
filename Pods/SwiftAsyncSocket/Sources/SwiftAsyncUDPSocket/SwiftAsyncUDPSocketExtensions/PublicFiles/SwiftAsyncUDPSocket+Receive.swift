//
//  SwiftAsyncUDPSocket+Receive.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2019/1/18.
//  Copyright © 2019 chouheiwa. All rights reserved.
//

import Foundation

// MARK: - Receive
extension SwiftAsyncUDPSocket {
    /// There are two modes of operation for receiving packets: one-at-a-time & continuous.
    ///
    /// In one-at-a-time mode, you call receiveOnce everytime your delegate is ready to process an incoming udp packet.
    /// Receiving packets one-at-a-time may be better suited for implementing certain state machine code,
    /// where your state machine may not always be ready to process incoming packets.
    ///
    /// In continuous mode, the delegate is invoked immediately everytime incoming udp packets are received.
    /// Receiving packets continuously is better suited to real-time streaming applications.
    ///
    /// You may switch back and forth between one-at-a-time mode and continuous mode.
    /// If the socket is currently in continuous mode, calling this method will switch it to one-at-a-time mode.
    ///
    /// When a packet is received (and not filtered by the optional receive filter),
    /// the delegate method (udpSocket:didReceiveData:fromAddress:withFilterContext:) is invoked.
    public func receiveOnce() throws {
        try socketQueueDoWithError {
            guard !flags.contains(.receiveOnce) else {
                return
            }

            guard flags.contains(.didCreatSockets) else {
                throw SwiftAsyncSocketError.badConfig(msg: "Must bind socket before you can receive data. " +
                    "You can do this explicitly via bind," +
                    " or implicitly via connect or by sending data."
                )
            }

            flags.insert(.receiveOnce)
            flags.remove(.receiveContinuous)

            // Here we use async because the caller is waiting
            socketQueue.async {
                self.doReceive()
            }
        }
    }
    /// There are two modes of operation for receiving packets: one-at-a-time & continuous.
    ///
    /// In one-at-a-time mode, you call receiveOnce everytime your delegate is ready to process an incoming udp packet.
    /// Receiving packets one-at-a-time may be better suited for implementing certain state machine code,
    /// where your state machine may not always be ready to process incoming packets.
    ///
    /// In continuous mode, the delegate is invoked immediately everytime incoming udp packets are received.
    /// Receiving packets continuously is better suited to real-time streaming applications.
    ///
    /// You may switch back and forth between one-at-a-time mode and continuous mode.
    /// If the socket is currently in continuous mode, calling this method will switch it to one-at-a-time mode.
    ///
    /// When a packet is received (and not filtered by the optional receive filter),
    /// the delegate method (udpSocket:didReceiveData:fromAddress:withFilterContext:) is invoked.
    public func receiveAlways() throws {
        try socketQueueDoWithError {
            guard !flags.contains(.receiveOnce) else {
                return
            }

            guard flags.contains(.didCreatSockets) else {
                throw SwiftAsyncSocketError.badConfig(msg: "Must bind socket before you can receive data. " +
                    "You can do this explicitly via bind," +
                    " or implicitly via connect or by sending data."
                )
            }

            flags.remove(.receiveOnce)
            flags.insert(.receiveContinuous)

            // Here we use async because the caller is waiting
            socketQueue.async {
                self.doReceive()
            }
        }
    }
    /// If the socket is currently receiving (receiveAlways has been called), this method pauses the receiving.
    /// That is, it won't read any more packets from the underlying OS socket until beginReceiving is called again.
    ///
    /// Important Note:
    /// SwiftAsyncUDPSocket may be running in parallel with your code.
    /// That is, your delegate is likely running on a separate thread/dispatch_queue.
    /// When you invoke this method, SwiftAsyncUDPSocket may have already dispatched delegate methods to be invoked.
    /// Thus, if those delegate methods have already been dispatch_async's doing,
    /// your didReceive delegate method may still be invoked after this method has been called.
    /// You should be aware of this, and program defensively.
    public func pauseReceiving() {
        socketQueueDo(async: true, {
            self.flags.remove([.receiveOnce, .receiveContinuous])

            if self.socket4FDBytesAvailable > 0 {
                self.suspendReceive4Source()
            }

            if self.socket6FDBytesAvailable > 0 {
                self.suspendReceive6Source()
            }
        })
    }

    /// See in the filter document
    ///
    /// - Parameter filter: filter
    public func setReceiveFilter(_ filter: SwiftAsyncUDPSocketReceiveFilter?) {
        socketQueueDo(async: true, {
            self.receiveFilter = filter
        })
    }
}
