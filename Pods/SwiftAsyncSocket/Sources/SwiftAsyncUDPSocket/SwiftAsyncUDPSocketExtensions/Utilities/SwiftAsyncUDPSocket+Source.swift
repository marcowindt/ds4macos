//
//  SwiftAsyncUDPSocket+Source.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2019/1/11.
//  Copyright © 2019 chouheiwa. All rights reserved.
//

import Foundation

extension SwiftAsyncUDPSocket {
    func suspendSend4Source() {
        suspendSource(flag: .send4SourceSuspended, source: send4Source)
    }

    func resumeSend4Source() {
        resumeSource(flag: .send4SourceSuspended, source: send4Source)
    }

    func suspendSend6Source() {
        suspendSource(flag: .send6SourceSuspended, source: send6Source)
    }

    func resumeSend6Source() {
        resumeSource(flag: .send6SourceSuspended, source: send6Source)
    }

    func suspendReceive4Source() {
        suspendSource(flag: .receive4SourceSuspended, source: receive4Source)
    }
    func resumeReceive4Source() {
        resumeSource(flag: .receive4SourceSuspended, source: receive4Source)
    }

    func suspendReceive6Source() {
        suspendSource(flag: .receive6SourceSuspended, source: receive6Source)
    }
    func resumeReceive6Source() {
        resumeSource(flag: .receive6SourceSuspended, source: receive6Source)
    }

    private func suspendSource(flag: SwiftAsyncUdpSocketFlags, source: DispatchSourceProtocol?) {
        guard let source = source, (!flags.contains(flag)) else { return }

        source.suspend()

        flags.insert(flag)
    }

    private func resumeSource(flag: SwiftAsyncUdpSocketFlags, source: DispatchSourceProtocol?) {
        guard let source = source, (flags.contains(flag)) else { return }

        source.resume()

        flags.remove(flag)
    }
}
