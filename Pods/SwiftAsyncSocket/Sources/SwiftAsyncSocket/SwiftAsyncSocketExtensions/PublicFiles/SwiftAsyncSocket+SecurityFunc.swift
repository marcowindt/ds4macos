//
//  SwiftAsyncSocket+SecurityFunc.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2019/1/2.
//  Copyright © 2019 chouheiwa. All rights reserved.
//

import Foundation
// MARK: - TLSSetting
extension SwiftAsyncSocket {
    public struct TLSSettings {
        /// set this to true if is server
        public var SSLIsServer: Bool = false
        /// Should SSL handshake trust by manually
        /// Set false or nil both effect trust automatic
        /// It can not set true if is server
        public var manuallyEvaluateTrust: Bool?

        public var SSLPeerName: String?
        /*
         * Specify this connection's certificate(s). This is mandatory for
         * server connections, optional for clients. Specifying a certificate
         * for a client enables SSL client-side authentication. The end-entity
         * cert is in certRefs[0]. Specifying a root cert is optional; if it's
         * not specified, the root cert which verifies the cert chain specified
         * here must be present in the system-wide set of trusted anchor certs.
         *
         * The certRefs argument is a CFArray containing SecCertificateRefs,
         * except for certRefs[0], which is a SecIdentityRef.
         *
         * Must be called prior to SSLHandshake(), or immediately after
         * SSLHandshake has returned errSSLClientCertRequested (i.e. before the
         * handshake is resumed by calling SSLHandshake again.)
         *
         * SecureTransport assumes the following:
         *
         *  -- The certRef references remain valid for the lifetime of the session.
         *  -- The certificate specified in certRefs[0] is capable of signing.
         *  -- The required capabilities of the certRef[0], and of the optional cert
         *     specified in SSLSetEncryptionCertificate (see below), are highly
         *     dependent on the application. For example, to work as a server with
         *     Netscape clients, the cert specified here must be capable of both
         *     signing and encrypting.
         */
        /// Here is the prompt of which is SSLCertificates contain
        /// We use SSLSetCertificate() function to set certificates
        public var SSLCertificates: [SecCertificate]?
        /// PeerID Data ,it is use for identifier SSL
        /// You can use String.data(using: .utf8) to get a data
        public var SSLPeerID: Data?

        public var SSLProtocolVersionMin: Int32?

        public var SSLProtocolVersionMax: Int32?

        public var SSLSessionOptionFalseStart: Bool?

        public var SSLSessionOptionSendOneByteRecord: Bool?

        public var SSLCipherSuites: [SSLCipherSuite]?
        #if !os(iOS)
        public var SSLDiffieHellmanParameters: Data?
        #endif

        #if os(iOS)
        public var useCFStreamForTLS: Bool?
        #endif

        public init() {}

        func toDictionary() -> [String: Any] {
            var dic: [String: Any] = [:]

            if let value = SSLPeerName {
                dic[kCFStreamSSLPeerName as String] = value
            }

            if let value = SSLCertificates {
                dic[kCFStreamSSLCertificates as String] = value
            }

            return dic
        }
    }

    public func startTLS(_ tlsSetting: TLSSettings? = nil) {
        let packet = SwiftAsyncSpecialPacket(tlsSetting ?? TLSSettings())
        socketQueueDo(sync: false) {
            guard self.flags.contains(.started) &&
                !self.flags.contains(.queuedTLS) &&
                !self.flags.contains(.forbidReadWrites) else {
                return
            }

            self.readQueue.append(packet)
            self.writeQueue.append(packet)

            self.flags.insert(.queuedTLS)

            self.maybeDequeueRead()
            self.maybeDequeueWrite()
        }
    }
}
