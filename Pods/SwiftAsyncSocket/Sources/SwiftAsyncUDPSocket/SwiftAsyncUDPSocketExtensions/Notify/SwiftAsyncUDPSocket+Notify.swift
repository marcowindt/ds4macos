//
//  SwiftAsyncUDPSocket+Notify.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2019/1/16.
//  Copyright © 2019 chouheiwa. All rights reserved.
//

import Foundation

extension SwiftAsyncUDPSocket {
    func notify(didReceive data: Data,
                from address: SwiftAsyncUDPSocketAddress,
                withFilterContext filterContext: Any?) {
        delegateQueue?.async {
            self.delegate?.updSocket(self,
                                     didReceive: data,
                                     from: address,
                                     withFilterContext: nil)
        }
    }
}
