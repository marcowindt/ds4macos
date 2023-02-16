//
//  SwiftAsyncSocket+UtilitiesGeting.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2018/12/19.
//  Copyright © 2018 chouheiwa. All rights reserved.
//

import Foundation

extension SwiftAsyncSocket {
    func getInterfaceAddress(url: URL) -> Data? {
        let path = url.path as NSString

        var nativeAddr = sockaddr_un()

        nativeAddr.sun_family = sa_family_t(AF_UNIX)

        let length = MemoryLayout.size(ofValue: nativeAddr.sun_path)

        strlcpy(nativeAddr.sun_path_pointer(), path.fileSystemRepresentation, length + 1)

        return Data(bytes: &nativeAddr, count: MemoryLayout.size(ofValue: nativeAddr))
    }
}
