//
//  SwiftAsyncUDPSocket+Receiving.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2019/1/15.
//  Copyright © 2019 chouheiwa. All rights reserved.
//

import Foundation

extension SwiftAsyncUDPSocket {
    func doReceive() {
        guard let isIPv4 = doReceiveFindKind() else {return}

        do {
            guard let data = try doReceive(type: SwiftAsyncUDPSocketAddress.Types(isSock4: isIPv4)) else {
                return
            }
            if flags.contains(.didConnect) {
                guard data.address == cachedConnectedAddress else {
                    doReceive()
                    return
                }
            }
            doReceiveEvluate(data: data)
        } catch let error as SwiftAsyncSocketError {
            close(error: error)
        } catch {
            fatalError("\(error)")
        }
    }

    func doReceiveEOF() {
        close(error: SwiftAsyncSocketError.connectionClosedError)
    }

    private func doReceiveFindKind() -> Bool? {
        let suspendBlock = {
            if self.socket4FDBytesAvailable > 0 {
                self.suspendReceive4Source()
            }

            if self.socket6FDBytesAvailable > 0 {
                self.suspendReceive6Source()
            }
        }
        guard flags.contains(.receiveOnce) || flags.contains(.receiveContinuous) else {
            suspendBlock()
            return nil
        }
        guard !(flags.contains(.receiveOnce) && pendingFilterOperations > 0) else {
            suspendBlock()
            return nil
        }

        guard socket4FDBytesAvailable > 0 || socket6FDBytesAvailable > 0 else {
            resumeReceive4Source()
            resumeReceive6Source()
            return nil
        }

        guard !flags.contains(.didConnect) else {
            return socket4FD != -1
        }

        guard socket4FDBytesAvailable > 0 else {
            return false
        }

        guard socket6FDBytesAvailable > 0 else {
            return true
        }

        defer {
            flags.formSymmetricDifference(.flipFlop)
        }
        return flags.contains(.flipFlop)
    }

    private func doReceiveEvluate(data: ReceiveData) {
        guard let receiveFilter = receiveFilter else {
            notify(didReceive: data.data, from: data.address, withFilterContext: nil)
            flags.remove(.receiveOnce)
            return
        }

        if receiveFilter.async {
            pendingFilterOperations += 1

            receiveFilter.queue.async {
                let (allowed, filterContext) = receiveFilter.filterBlock(data.data, data.address)

                self.socketQueue.async {
                    self.pendingFilterOperations -= 1

                    if allowed {
                        self.notify(didReceive: data.data, from: data.address, withFilterContext: filterContext)
                    }

                    guard self.flags.contains(.receiveOnce) else {
                        return
                    }

                    if allowed {
                        self.flags.remove(.receiveOnce)
                    } else if self.pendingFilterOperations == 0 {
                        self.doReceive()
                    }
                }
            }
        } else {
            var result = false
            var filterContext: Any?
            receiveFilter.queue.sync {
                (result, filterContext) = receiveFilter.filterBlock(data.data, data.address)
            }

            if result {
                notify(didReceive: data.data, from: data.address, withFilterContext: filterContext)
                flags.remove(.receiveOnce)
            } else {
                self.doReceive()
            }
        }
    }
}

private extension SwiftAsyncUDPSocket {
    private struct ReceiveData {
        let address: SwiftAsyncUDPSocketAddress
        let data: Data
    }

    private func doReceive(type: SwiftAsyncUDPSocketAddress.Types) throws -> ReceiveData? {
        var bufSize: Int = 0
        var (buf, (result, addressData)) = doReceivePreformRecv(type: type, bufSize: &bufSize)

        if result > 0 {
            switch type {
            case .socket4:
                if result >= socket4FDBytesAvailable {
                    socket4FDBytesAvailable = 0
                } else {
                    socket4FDBytesAvailable -= UInt(result)
                }
            case .socket6:
                if result >= socket6FDBytesAvailable {
                    socket6FDBytesAvailable = 0
                } else {
                    socket6FDBytesAvailable -= UInt(result)
                }
            }

            if result != bufSize {
                buf = realloc(buf, result)
            }

            let data = Data(bytesNoCopy: buf, count: result, deallocator: .free)
            let address = SwiftAsyncUDPSocketAddress(type: type,
                                                     address: addressData)

            return ReceiveData(address: address,
                               data: data)
        } else {
            switch type {
            case .socket4:
                socket4FDBytesAvailable = 0
            case .socket6:
                socket6FDBytesAvailable = 0
            }
            free(buf)

            try doReceiveJudgeError(result: result)
            return nil
        }
    }

    private func doReceivePreformRecv(type: SwiftAsyncUDPSocketAddress.Types,
                                      bufSize: inout Int) -> (UnsafeMutableRawPointer, (Int, Data)) {
        var sockAddr: Any
        var sockFD: Int32
        switch type {
        case .socket4:
            sockAddr = sockaddr_in()
            bufSize = Int(max4ReceiveSizeStore)
            sockFD = socket4FD
        case .socket6:
            sockAddr = sockaddr_in6()
            bufSize = Int(max6ReceiveSizeStore)
            sockFD = socket6FD
        }

        var sockaddr6len = socklen_t(MemoryLayout.size(ofValue: sockAddr))

        guard let buf = malloc(bufSize) else {
            assert(false, "Can not malloc() here")
            fatalError("malloc() false")
        }

        let sockPointer = withUnsafeMutablePointer(to: &sockAddr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1, {$0})
        }
        let result = Darwin.recvfrom(sockFD, buf, bufSize, 0, sockPointer, &sockaddr6len)

        return (buf, (result, Data(bytes: sockPointer, count: Int(sockaddr6len))))
    }

    private func doReceiveJudgeError(result: Int) throws {
        assert(result <= 0, "Invild logic")
        guard result == 0 || (result < 0 && errno == EAGAIN) else {
            throw SwiftAsyncSocketError.errno(code: errno, reason: "Error in recvfrom() function")
        }

        if socket4FDBytesAvailable > 0 {
            resumeReceive4Source()
        }
        if socket6FDBytesAvailable > 0 {
            resumeReceive6Source()
        }
    }
}
