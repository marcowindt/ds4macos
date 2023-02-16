//
//  SwiftAsyncSocket+Sock.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2018/12/20.
//  Copyright © 2018 chouheiwa. All rights reserved.
//

import Foundation

extension SwiftAsyncSocket {
    func bind(_ sockFD: Int32,
              toInterface connectInterface: Data?) throws {
        guard let connectInterface = connectInterface else { return }

        let helper = SockDataHelper(data: connectInterface)

        if helper.port > 0 {
            var reuseOn = 1

            Darwin.setsockopt(sockFD,
                              SOL_SOCKET,
                              SO_REUSEADDR,
                              &reuseOn,
                              socklen_t(MemoryLayout.size(ofValue: reuseOn)))
        }

        let interfaceAddr: UnsafePointer<sockaddr> = connectInterface.convert()

        let result = Darwin.bind(sockFD, interfaceAddr, socklen_t(connectInterface.count))

        guard result == 0 else {
            throw SwiftAsyncSocketError.errno(code: errno, reason: "Error in bind() function")
        }
    }

    enum SocketFamilyType {
        case IPv4
        case IPv6

        var rawValue: Int32 {
            switch self {
            case .IPv4:
                return Darwin.AF_INET
            case .IPv6:
                return Darwin.AF_INET6
            }
        }
    }

    func createSock(_ family: SocketFamilyType, connectinterface: Data?) throws -> Int32 {
        // socket() function
        let socketFD = Darwin.socket(family.rawValue, SOCK_STREAM, 0)

        guard socketFD != SwiftAsyncSocketKeys.socketNull else {
            throw SwiftAsyncSocketError.errno(code: errno, reason: "Error in socket() function")
        }

        do {
            try bind(socketFD, toInterface: connectinterface)
        } catch let error as SwiftAsyncSocketError {
            closeSocket(error: error)
        } catch {
            fatalError("\(error)")
        }

        // Prevent SIGPIPE signals
        var nosigpipe = 1
        Darwin.setsockopt(socketFD,
                          SOL_SOCKET,
                          SO_NOSIGPIPE,
                          &nosigpipe,
                          socklen_t(MemoryLayout.size(ofValue: nosigpipe)))

        return socketFD
    }

    func connectSock(_ socketFD: Int32, address: Data, stateIndex: Int) {
        guard !isConnected else {
            close(socketFD)
            return
        }
        DispatchQueue.global().async { [weak self] in
            guard let `self` = self else { return }
            var pointer: UnsafePointer<sockaddr> = address.convert()
            let result = Darwin.connect(socketFD,pointer, socklen_t(address.count))
            let err = errno
            self.socketQueue.async {
                guard !self.isConnected else {
                    self.close(socketFD)
                    return
                }
                if result == 0 {
                    self.closeUnuseSock(usedSocketFD: socketFD)

                    self.didConnect(stateIndex)
                } else {
                    self.close(socketFD)

                    guard self.socket4FD != SwiftAsyncSocketKeys.socketNull ||
                        self.socket4FD != SwiftAsyncSocketKeys.socketNull else {
                        self.closeSocket(error: SwiftAsyncSocketError.errno(code: err,
                                                                            reason: "Error in connect() function"))
                        return
                    }
                }
            }
        }
    }

    func close(_ socketFD: Int32) {
        guard socketFD != SwiftAsyncSocketKeys.socketNull &&
        (socketFD == socket4FD || socketFD == socket6FD)
        else {
            return
        }
        // Socket may use in mutable processes,
        // we only close our process's socket connnection,
        // but the socket maybe still alive.
        // If there was no other connection, the socket will be close.
        Darwin.close(socketFD)

        if socketFD == socket4FD {
            socket4FD = SwiftAsyncSocketKeys.socketNull
        } else {
            socket6FD = SwiftAsyncSocketKeys.socketNull
        }
    }

    func closeUnuseSock(usedSocketFD: Int32) {
        if usedSocketFD != socket4FD {
            Darwin.close(socket4FD)
        } else if usedSocketFD != socket6FD {
            Darwin.close(socket6FD)
        }
    }
}
