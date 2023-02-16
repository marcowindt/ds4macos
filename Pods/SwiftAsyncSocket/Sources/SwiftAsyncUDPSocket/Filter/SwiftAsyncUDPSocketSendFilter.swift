//
//  SwiftAsyncUDPSocketSendFilter.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2019/1/11.
//  Copyright © 2019 chouheiwa. All rights reserved.
//
import Foundation
/// This struct can help you to filter send data
/// A filter can provide several interesting possibilities:
///
/// 1. Optional caching of resolved addresses for domain names.
///    The cache could later be consulted, resulting in fewer system calls to getaddrinfo.
///
/// 2. Reusable modules of code for bandwidth monitoring.
///
/// 3. Sometimes traffic shapers are needed to simulate real world environments.
///    A filter allows you to write custom code to simulate such environments.
///    The ability to code this yourself is especially helpful when your simulated environment
///    is more complicated than simple traffic shaping (e.g. simulating a cone port restricted router),
///    or the system tools to handle this aren't available (e.g. on a mobile device).
public struct SwiftAsyncUDPSocketSendFilter: SwiftAsyncUDPSocketFilter {
    /// - Parameters:
    ///   - $0: the packet that was sent
    ///   - $1: The address of the data sent to
    ///   - $2: The tag of the sent data
    /// - Returns:
    ///   - $0: true if the received packet should be passed onto the delegate.
    ///         false if the received packet should be discarded, and not reported to the delegete.
    public typealias BlockType = (Data, SwiftAsyncUDPSocketAddress, Int) -> Bool

    public var filterBlock: BlockType

    public var queue: DispatchQueue

    /// If we should use async
    public var async: Bool

    public init(filterBlock: @escaping BlockType, queue: DispatchQueue, async: Bool) {
        self.filterBlock = filterBlock
        self.queue = queue
        self.async = async
    }
}
