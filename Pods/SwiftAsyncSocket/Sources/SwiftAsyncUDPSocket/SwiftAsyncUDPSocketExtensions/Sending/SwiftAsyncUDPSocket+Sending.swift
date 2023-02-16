//
//  SwiftAsyncUDPSocket+Sending.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2019/1/15.
//  Copyright © 2019 chouheiwa. All rights reserved.
//

import Foundation

extension SwiftAsyncUDPSocket {
    func maybeDequeueSend() {
        assert(DispatchQueue.getSpecific(key: queueKey) != nil, "Must be dispatched on socketQueue")
        // If we already have a send operation, then this function will do nothing
        guard currentSend == nil else {
            return
        }

        if !flags.contains(.didCreatSockets) {
            // Here means the socket has not been created
            // Then we created it
            do {
                try createSocket(IPv4: isIPv4Enable, IPv6: isIPv6Enable)
            } catch let error as SwiftAsyncSocketError {
                close(error: error)
                return
            } catch {
                fatalError("\(error)")
            }
        }

        while sendQueue.count > 0 {
            currentSend = sendQueue.remove(at: 0)

            guard let currentSend = currentSend as? SwiftAsyncUDPSendPacket else {
                // The code will be here because that socket has not connected
                // This function will be invoked, if the socket connected
                maybeConnect()
                return
            }

            if let resolvedError = currentSend.resolvedError {
                delegateQueue?.async {
                    self.delegate?.updSocket(self,
                                             didNotSendDataWith: currentSend.tag,
                                             dueTo: resolvedError)
                }

                self.currentSend = nil
                continue
            }

            doPreSend()
            break
        }

        if currentSend == nil && flags.contains(.closeAfterSends) {
            close(error: nil)
        }
    }

    func doPreSend() {
        guard let currentSend = currentSend as? SwiftAsyncUDPSendPacket else {
            assert(false, "Current send can not be nil or other class at here")
            return
        }
        //
        // 1. Check for problems with send packet
        //
        guard doPreSendCheckProblem(currentSend: currentSend) else {return}
        //
        // 2. Query send filter (if applicable)
        //
        guard let sendFilter = sendFilter else {
            //
            // 3. No sendFilter. Just sending
            //
            doSend()
            return
        }
        // query sendFilter
        let filterDone: (Bool) -> Void = {
            if $0 {
                self.doSend()
            } else {
                self.delegateQueue?.async {
                    self.delegate?.updSocket(self, didSendDataWith: currentSend.tag)
                }
            }
        }
        guard let address = currentSend.address else {
            assert(false, "Logic error")
            return
        }

        if sendFilter.async {
            currentSend.filterInProgress = true

            sendFilter.queue.async {
                let allowed = sendFilter.filterBlock(currentSend.buffer,
                                                     address,
                                                     currentSend.tag)
                self.socketQueue.async {
                    currentSend.filterInProgress = false

                    guard let send = self.currentSend as? SwiftAsyncUDPSendPacket,
                        (send === currentSend) else {return}

                    filterDone(allowed)
                }
            }
        } else {
            var allowed = true

            socketQueueDo {
                allowed = sendFilter.filterBlock(currentSend.buffer,
                                                 address,
                                                 currentSend.tag)
            }

            filterDone(allowed)
        }
    }

    private func doPreSendCheckProblem(currentSend: SwiftAsyncUDPSendPacket) -> Bool {
        let errorDone: (SwiftAsyncSocketError) -> Void = { (error) in
            self.delegateQueue?.async {
                self.delegate?.updSocket(self, didNotSendDataWith: currentSend.tag, dueTo: error)
            }

            self.endCurrentSend()
            self.maybeDequeueSend()
        }

        if flags.contains(.didConnect) {
            guard currentSend.resolvedError == nil &&
                currentSend.resolvedAddresses == nil &&
                !currentSend.resolveInProgress else {
                    errorDone(SwiftAsyncSocketError.badConfig(msg:
                        "Cannot specify destination of packet for connected socket"))
                    return false
            }

            currentSend.address = cachedConnectedAddress
        } else {
            guard !currentSend.resolveInProgress else {
                if flags.contains(.sock4CanAcceptBytes) {
                    suspendSend4Source()
                }

                if flags.contains(.sock6CanAcceptBytes) {
                    suspendSend6Source()
                }
                return false
            }

            if let error = currentSend.resolvedError {
                errorDone(error)
                return false
            }

            if currentSend.address == nil {
                guard let resolvedAddresses = currentSend.resolvedAddresses else {
                    errorDone(SwiftAsyncSocketError.badConfig(msg:
                        "You must specify destination of packet for a non-connected socket"))
                    return false
                }

                do {
                    currentSend.address = try get(from: resolvedAddresses)
                } catch let error as SwiftAsyncSocketError {
                    errorDone(error)
                    return false
                } catch {
                    fatalError("\(error)")
                }
            }
        }
        return true
    }

    func doSend() {
        guard let currentSend = currentSend as? SwiftAsyncUDPSendPacket else {
            assert(false, "Invild Logic")
            return
        }

        guard let address = currentSend.address else {
            assert(false, "Invild Logic")
            return
        }

        var result = 0

        let socketFD: Int32 = address.type == .socket4 ? socket4FD : socket6FD

        if flags.contains(.didConnect) {
            // Connected socket
            result = Darwin.send(socketFD,
                                 currentSend.buffer.convert(),
                                 currentSend.buffer.count, 0)
        } else {
            result = Darwin.sendto(socketFD,
                                   currentSend.buffer.convert(),
                                   currentSend.buffer.count, 0,
                                   address.address.convert(),
                                   socklen_t(address.address.count))
        }
        // If the socket wasn't binding before, now is the time
        if !flags.contains(.didBind) {
            flags.insert(.didBind)
        }
        // Check result
        guard result > 0 else {
            guard result == 0 || errno == EAGAIN else {
                self.close(error: SwiftAsyncSocketError.errno(code: errno,
                                                              reason: "Error in send() function."))
                return
            }
            // Not enough room in the underlying OS socket send buffer.
            // Wait for a notification of available space.
            if !flags.contains(.sock4CanAcceptBytes) {
                resumeSend4Source()
            }

            if !flags.contains(.sock6CanAcceptBytes) {
                resumeSend6Source()
            }

            if sendTimer == nil && currentSend.timeout >= 0 {
                setupSendTimer(timeout: currentSend.timeout)
            }
            return
        }
        // Send complete
        delegateQueue?.async {
            self.delegate?.updSocket(self, didSendDataWith: currentSend.tag)
        }
        endCurrentSend()
        maybeDequeueSend()
    }

    func createSocket(IPv4: Bool, IPv6: Bool) throws {
        assert(DispatchQueue.getSpecific(key: queueKey) == self, "Must be dispatched on socketQueue")
        assert(!flags.contains(.didCreatSockets), "Sockets have already been created")

        if IPv4 {
            try createSocket4()
        }

        if IPv6 {
            try createSocket6()
        }

    }

    func createSocket4() throws {
        socket4FD = try createSocket(domain: AF_INET)

        setupSendAndReceiveSources(isSocket4: true)

        flags.insert(.didCreatSockets)
    }

    func createSocket6() throws {
        socket6FD = try createSocket(domain: AF_INET6)

        setupSendAndReceiveSources(isSocket4: false)

        flags.insert(.didCreatSockets)
    }

    private func createSocket(domain: Int32) throws -> Int32 {
        assert(DispatchQueue.getSpecific(key: queueKey) == self, "Must be dispatched on socketQueue")

        let socketFD = Darwin.socket(domain, SOCK_DGRAM, 0)

        guard socketFD != SwiftAsyncSocketKeys.socketNull else {
            throw SwiftAsyncSocketError.errno(code: Darwin.errno,
                                              reason: "Error in socket() function")
        }

        guard Darwin.fcntl(socketFD, F_SETFL, O_NONBLOCK) != -1 else {
            Darwin.close(socketFD)

            throw SwiftAsyncSocketError.errno(code: Darwin.errno,
                                              reason: "Error enabling non-blocking IO on socket (fcntl)")
        }
        var resueaddr = 1
        var result: Int32 = Darwin.setsockopt(socketFD, SOL_SOCKET, SO_REUSEADDR, &resueaddr,
                                              socklen_t(MemoryLayout.size(ofValue: resueaddr)))

        guard result != -1 else {
            Darwin.close(socketFD)
            throw SwiftAsyncSocketError.errno(code: Darwin.errno,
                                              reason: "Error enabling address reuse (setsockopt)")
        }

        var nosigpipe = 1
        result = Darwin.setsockopt(socketFD, SOL_SOCKET, SO_NOSIGPIPE, &nosigpipe,
                                   socklen_t(MemoryLayout.size(ofValue: nosigpipe)))

        guard result != -1 else {
            Darwin.close(socketFD)
            throw SwiftAsyncSocketError.errno(code: Darwin.errno,
                                              reason: "Error enabling address reuse (setsockopt)")
        }

        var maxSendSize = Int(maxSendSizeStore)

        result = Darwin.setsockopt(socketFD, SOL_SOCKET, SO_SNDBUF,
                                   &maxSendSize,
                                   4)

        guard result != -1 else {
            Darwin.close(socketFD)
            throw SwiftAsyncSocketError.errno(code: Darwin.errno,
                                              reason: "Error setting send buffer size (setsockopt)")
        }

        result = Darwin.setsockopt(socketFD, SOL_SOCKET, SO_RCVBUF,
                                   &maxSendSize,
                                   socklen_t(MemoryLayout<Int32>.size))

        guard result != -1 else {
            Darwin.close(socketFD)
            throw SwiftAsyncSocketError.errno(code: Darwin.errno,
                                              reason: "Error setting receive buffer size (setsockopt)")
        }

        return socketFD
    }

    func endCurrentSend() {
        sendTimer?.cancel()
        sendTimer = nil

        currentSend = nil
    }

    func doSendTimeout() {
        guard let currentSend = currentSend as? SwiftAsyncUDPSendPacket else {
            assert(false, "Logic error")
            return
        }
        delegateQueue?.async {
            self.delegate?.updSocket(self,
                                     didNotSendDataWith: currentSend.tag,
                                     dueTo: SwiftAsyncSocketError.connectTimeoutError)
        }

        endCurrentSend()
        maybeDequeueSend()
    }

    func setupSendTimer(timeout: TimeInterval) {
        assert(sendTimer == nil, "Logic error")
        assert(timeout >= 0, "Logic error")

        sendTimer = DispatchSource.makeTimerSource(flags: [], queue: socketQueue)

        sendTimer?.setEventHandler(handler: {
            self.doSendTimeout()
        })

        sendTimer?.schedule(deadline: DispatchTime.now() + timeout,
                            repeating: .never,
                            leeway: .nanoseconds(0))

        sendTimer?.resume()
    }
}
