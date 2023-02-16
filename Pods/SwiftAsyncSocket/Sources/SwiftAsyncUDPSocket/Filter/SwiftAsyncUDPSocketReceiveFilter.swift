//
//  SwiftAsyncUDPSocketReceiveFilter.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2019/1/11.
//  Copyright © 2019 chouheiwa. All rights reserved.
//

import Foundation

/// This struct can help you to filter the data recevie from the socekt
/// Why we use filter?
/// A filter can provide several useful features:
///
/// 1. Many times udp packets need to be parsed.
///    Since the filter can run in its own independent queue, you can parallelize this parsing quite easily.
///    The end result is a parallel socket io, datagram parsing, and packet processing.
///
/// 2. Many times udp packets are discarded because they are duplicate/unneeded/unsolicited.
///    The filter can prevent such packets from arriving at the delegate.
///    And because the filter can run in its own independent queue, this doesn't slow down the delegate.
///
///    - Since the udp protocol does not guarantee delivery, udp packets may be lost.
///      Many protocols built atop udp thus provide various resend/re-request algorithms.
///      This sometimes results in duplicate packets arriving.
///      A filter may allow you to architect the duplicate detection code to run in parallel to normal processing.
///
///    - Since the udp socket may be connectionless, its possible for unsolicited packets to arrive.
///      Such packets need to be ignored.
///
/// 3. Sometimes traffic shapers are needed to simulate real world environments.
///    A filter allows you to write custom code to simulate such environments.
///    The ability to code this yourself is especially helpful when your simulated environment
///    is more complicated than simple traffic shaping (e.g. simulating a cone port restricted router),
///    or the system tools to handle this aren't available (e.g. on a mobile device).
public struct SwiftAsyncUDPSocketReceiveFilter: SwiftAsyncUDPSocketFilter {
    /// - Parameters:
    ///   - $0: the packet that was received
    ///   - $1: The address of the data received from
    /// - Returns:
    ///   - $0: true if the received packet should be passed onto the delegate.
    ///         false if the received packet should be discarded, and not reported to the delegete.
    ///   - $1: The context you want to identifier to the delegate
    public typealias BlockType = (Data, SwiftAsyncUDPSocketAddress) -> (Bool, Any?)

    public let filterBlock: BlockType

    public let queue: DispatchQueue

    public let async: Bool

    public init(filterBlock: @escaping BlockType, queue: DispatchQueue, async: Bool) {
        self.filterBlock = filterBlock
        self.queue = queue
        self.async = async
    }
}
