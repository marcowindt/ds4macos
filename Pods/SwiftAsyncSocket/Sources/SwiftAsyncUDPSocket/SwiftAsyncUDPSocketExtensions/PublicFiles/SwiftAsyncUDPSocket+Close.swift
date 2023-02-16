//
//  SwiftAsyncUDPSocket+Close.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2019/1/18.
//  Copyright © 2019 chouheiwa. All rights reserved.
//

import Foundation
// MARK: - close
extension SwiftAsyncUDPSocket {

    public func close() {
        socketQueueDo {
            self.close(error: nil)
        }
    }

    public func closeAfterSends() {
        socketQueueDo {
            self.flags.insert(.closeAfterSends)

            if self.currentSend == nil && self.sendQueue.count == 0 {
                self.close(error: nil)
            }
        }
    }
}
