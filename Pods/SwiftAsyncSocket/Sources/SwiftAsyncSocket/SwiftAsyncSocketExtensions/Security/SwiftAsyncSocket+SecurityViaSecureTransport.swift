//
//  SwiftAsyncSocket+SecurityViaSecureTransport.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2018/12/13.
//  Copyright © 2018 chouheiwa. All rights reserved.
//

import Foundation

extension SwiftAsyncSocket {
    func maybeStartTLS() {
        // We can't start TLS until:
        // - All queued reads prior to the user calling startTLS are complete
        // - All queued writes prior to the user calling startTLS are complete
        //
        // We'll know these conditions are met when both kStartingReadTLS and kStartingWriteTLS are set

        // 我们不能开始TLS操作直到:
        //
        // - 所有读操作已经完成
        // - 所有写操作已经完成
        //
        // 当flags中包含SwiftAsyncSocketFlags.startingWritingTLS和SwiftAsyncSocketFlags.startingWritingTLS的时候，以上条件都满足了

        guard flags.contains([.startingWritingTLS, .startingReadTLS]) else {return}

        var useSecureTransport = true

        #if os(iOS)
        guard let tlsPacket = currentRead as? SwiftAsyncSpecialPacket else {return}

        if let value = tlsPacket.tlsSettings.useCFStreamForTLS,
            (value) {
            useSecureTransport = false
        }
        #endif

        if useSecureTransport {
            ssl_startTLS()
        } else {
            #if os(iOS)
            cf_startTLS()
            #endif
        }
    }

    func ssl_continueSSLHandshake() {
        guard let sslContext = sslContext else {
            closeSocket(error: SwiftAsyncSocketError(msg: "Error in SSLCreateContext"))
            return
        }

        // If the return value is noErr, the session is ready for normal secure communication.
        // If the return value is errSSLWouldBlock, the SSLHandshake function must be called again.
        // If the return value is errSSLServerAuthCompleted, we ask delegate if we should trust the
        // server and then call SSLHandshake again to resume the handshake or close the connection
        // errSSLPeerBadCert SSL error.
        // Otherwise, the return value indicates an error code.

        // 当返回的结果是noErr时，会话已经准备好开始正常安全通讯了
        // 当返回的结果是errSSLWouldBlock时，SSLHandshake必须被再次调用
        // 当返回的结果是errSSLServerAuthCompleted时，我们询问delagate我们是否应该相信服务器，然后调用SSLHandshake以继续握手或者直接关闭连接
        // 当返回的结果是errSSLPeerBadCert时，SSL出现错误
        // 否则，返回值便是其错误码

        let status = Security.SSLHandshake(sslContext)
        lastSSLHandshakeError = status

        switch status {
        case noErr:
            flags.remove([.startingReadTLS, .startingWritingTLS])
            flags.insert(.isSecure)

            delegateQueue?.async {
                self.delegate?.socketDidSecure(self)
            }

            endCurrentRead()
            endCurrentWrite()

            maybeDequeueRead()
            maybeDequeueWrite()
        case Security.errSSLPeerAuthCompleted:
            var trust: SecTrust?

            guard Security.SSLCopyPeerTrust(sslContext, &trust) == noErr else {
                closeSocket(error: SwiftAsyncSocketError.sslError(code: status))
                return
            }

            guard let trustSec = trust else {assert(false, "Logic Invid");fatalError("Logic invid")}

            let aStateIndex = stateIndex

            let comletionHandler: (Bool) -> Void = { [weak self] (shouldTrust) in
                self?.socketQueue.async {
                    self?.ssl_shouldTrustPeer(shouldTrust, stateIndex: aStateIndex)
                }
            }

            delegateQueue?.async {
                guard self.delegate?.socket(self,
                                            didReceive: trustSec,
                                            completionHandler: comletionHandler) ?? false else {
                    self.closeSocket(error: SwiftAsyncSocketError(msg:
                        "SwiftAsyncSocketManuallyEvaluateTrust specified in tlsSettings " +
                        ",but delegate doesn't implement socket:shouldTrustPeer: or return is false"))
                    return
                }
            }
        case Security.errSSLWouldBlock:
            // Handshake continues...
            //
            // This method will be called again from doReadData or doWriteData.
            break
        default:
            closeSocket(error: SwiftAsyncSocketError.sslError(code: status))
        }

    }

    func ssl_shouldTrustPeer(_ shouldTrust: Bool, stateIndex aStateIndex: Int) {
        guard aStateIndex == stateIndex else {
            // One of the following is false
            // - the socket was disconnected
            // - the startTLS operation timed out
            // - the completionHandler was already invoked once
            return
        }

        stateIndex += 1

        guard shouldTrust else {
            assert(lastSSLHandshakeError == Security.errSSLPeerAuthCompleted,
                   "ssl_shouldTrustPeer called when last error is \(lastSSLHandshakeError) " +
                "and not errSSLPeerAuthCompleted")
            closeSocket(error: SwiftAsyncSocketError.sslError(code: Security.errSSLPeerBadCert))
            return
        }

        ssl_continueSSLHandshake()
    }
}
