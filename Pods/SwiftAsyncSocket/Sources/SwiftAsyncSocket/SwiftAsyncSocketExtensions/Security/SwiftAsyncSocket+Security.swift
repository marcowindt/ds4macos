//
//  SwiftAsyncSocket+Security.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2018/12/19.
//  Copyright © 2018 chouheiwa. All rights reserved.
//

import Foundation

extension SwiftAsyncSocket {
    func ssl_startTLS() {
        do {
            var isServer = false

            let (currentRead, sslContext) = try ssl_startTLSCreatSSLContext(isServer: &isServer)

            try ssl_startTLSSetIOFuncs(sslContext: sslContext)

            try ssl_startTLSSetConnection(sslContext: sslContext)

            // Configure SSLContext from given settings
            //
            // Checklist:
            //  1. kCFStreamSSLPeerName
            //  2. kCFStreamSSLCertificates
            //  3. GCDAsyncSocketSSLPeerID
            //  4. GCDAsyncSocketSSLProtocolVersionMin
            //  5. GCDAsyncSocketSSLProtocolVersionMax
            //  6. GCDAsyncSocketSSLSessionOptionFalseStart
            //  7. GCDAsyncSocketSSLSessionOptionSendOneByteRecord
            //  8. GCDAsyncSocketSSLCipherSuites
            //  9. GCDAsyncSocketSSLDiffieHellmanParameters (Mac)
            //
            // Deprecated (throw error):
            // 10. kCFStreamSSLAllowsAnyRoot
            // 11. kCFStreamSSLAllowsExpiredRoots
            // 12. kCFStreamSSLAllowsExpiredCertificates
            // 13. kCFStreamSSLValidatesCertificateChain
            // 14. kCFStreamSSLLevel

            try ssl_startTLSSetMannuallyTrust(currentRead: currentRead,
                                              sslContext: sslContext,
                                              isServer: isServer)
            //            var list = [ssl_startTLSSetkCFStreamSSLPeerName]
            //  1. kCFStreamSSLPeerName
            try ssl_startTLSSetkCFStreamSSLPeerName(currentRead: currentRead, sslContext: sslContext)
            // 2. kCFStreamSSLCertificates
            try ssl_startTLSSetkCFStreamSSLCertificates(currentRead: currentRead, sslContext: sslContext)
            // 3. SwiftAsyncSocketSSLPeerID
            try ssl_startTLSSetSwiftAsyncSocketSSLPeerID(currentRead: currentRead, sslContext: sslContext)
            // 4. SwiftAsyncSocketSSLProtocolVersionMin
            try ssl_startTLSSetSwiftAsyncSocketSSLProtocolVersionMin(currentRead: currentRead, sslContext: sslContext)
            // 5. SwiftAsyncSocketSSLProtocolVersionMax
            try ssl_startTLSSetSwiftAsyncSocketSSLProtocolVersionMax(currentRead: currentRead, sslContext: sslContext)
            // 6. SwiftAsyncSocketSSLSessionOptionFalseStart
            try ssl_startTLSSetSSLSessionOptionFalseStart(currentRead: currentRead, sslContext: sslContext)
            // 7. SwiftAsyncSocketSSLSessionOptionSendOneByteRecord
            try ssl_startTLSSetSSLSessionOptionSendOneByteRecord(currentRead: currentRead, sslContext: sslContext)
            // 8. SwiftAsyncSocketSSLCipherSuites
            try ssl_startTLSSetSSLCipherSuites(currentRead: currentRead, sslContext: sslContext)
            #if !os(iOS)
            // 9. SwiftAsyncSocketSSLDiffieHellmanParameters
            try ssl_startTLSSetSSLDiffieHellmanParameters(currentRead: currentRead, sslContext: sslContext)
            #endif
            // Setup the sslPreBuffer
            //
            // Any data in the preBuffer needs to be moved into the sslPreBuffer,
            // as this data is now part of the secure read stream.

            // 初始化 ssl 缓存
            // 在预缓存区中的所有数据都需要被移动到ssl缓存区中
            // 这些数据现在都是安全流数据
            let sslBuffer = delegate?.socketNeedBuffer(self) ?? SwiftAsyncSocketPreBuffer(capacity: 1024 * 4)

            sslPreBuffer = sslBuffer

            let space = sslBuffer.availableBytes

            if space > 0 {
                sslBuffer.ensureCapacityForWrite(capacity: space)

                Darwin.memcpy(UnsafeMutableRawPointer(sslBuffer.readPointer),
                       UnsafeMutableRawPointer(preBuffer.readPointer),
                       space)

                preBuffer.didRead(space)
                sslBuffer.didWrite(space)
            }

            sslErrCode = noErr
            lastSSLHandshakeError = noErr

            ssl_continueSSLHandshake()
        } catch let error as SwiftAsyncSocketError {
            closeSocket(error: error)
            return
        } catch {
            fatalError("\(error)")
        }
    }

    private func ssl_startTLSCreatSSLContext(isServer: inout Bool) throws -> (
        SwiftAsyncSpecialPacket,
        SSLContext) {
        guard let currentRead = currentRead as? SwiftAsyncSpecialPacket else {
            throw SwiftAsyncSocketError(msg: "Logic error")
        }

        isServer = currentRead.tlsSettings.SSLIsServer

        sslContext = Security.SSLCreateContext(kCFAllocatorDefault, isServer ? .serverSide : .clientSide, .streamType)

        guard let sslContext = sslContext else {
            throw SwiftAsyncSocketError(msg: "Error in SSLCreateContext")
        }

        return (currentRead, sslContext)
    }

    private func ssl_startTLSSetIOFuncs(sslContext: SSLContext) throws {
        let status = Security.SSLSetIOFuncs(sslContext, { (ref, data, dataLength) -> OSStatus in
            let `self`  = Unmanaged<SwiftAsyncSocket>
                .fromOpaque(ref)
                .takeUnretainedValue()

            assert(DispatchQueue.getSpecific(key: self.queueKey) != nil, "What the deuce?")

            return self.sslRead(buffer: data, length: dataLength)
        }, { (ref, data, dataLength) -> OSStatus in
            let `self` = Unmanaged<SwiftAsyncSocket>
                .fromOpaque(ref)
                .takeUnretainedValue()

            assert(DispatchQueue.getSpecific(key: self.queueKey) != nil, "What the deuce?")

            return self.sslWrite(buffer: UnsafeMutableRawPointer(mutating: data), length: dataLength)
        })

        guard status == noErr else { throw SwiftAsyncSocketError(msg: "Error in SSLSetIOFuncs") }
    }

    private func ssl_startTLSSetConnection(sslContext: SSLContext) throws {
        let pointer = Unmanaged.passUnretained(self).toOpaque()

        let status = Security.SSLSetConnection(sslContext,
                                               pointer)

        guard status == noErr else { throw SwiftAsyncSocketError(msg: "Error in SSLSetConnection") }
    }

    private func ssl_startTLSSetMannuallyTrust(currentRead: SwiftAsyncSpecialPacket,
                                               sslContext: SSLContext,
                                               isServer: Bool) throws {
        guard let manual = currentRead.tlsSettings.manuallyEvaluateTrust,
            (manual)
            else { return }

        guard !isServer else {
            throw SwiftAsyncSocketError(msg:
                "Manual trust validation is not supported for server sockets")
        }

        let status = Security.SSLSetSessionOption(sslContext, .breakOnServerAuth, true)

        guard status == noErr else {
            throw SwiftAsyncSocketError(msg: "Error in SSLSetSessionOption")
        }
    }

    private func ssl_startTLSSetkCFStreamSSLPeerName(currentRead: SwiftAsyncSpecialPacket,
                                                     sslContext: SSLContext) throws {
        guard let value = currentRead.tlsSettings.SSLPeerName else { return }

        guard let data = value.data(using: .utf8) else {
            assert(false, SwiftAsyncSocketAssertError.stringDataError.description)
            throw SwiftAsyncSocketError(msg: SwiftAsyncSocketAssertError.stringDataError.description)
        }

        let peer: UnsafePointer<Int8> = data.convert()

        let status = Security.SSLSetPeerDomainName(sslContext, peer, data.count)

        guard status == noErr else {
            throw SwiftAsyncSocketError(msg: "Error in SSLSetPeerDomainName")
        }
    }

    private func ssl_startTLSSetkCFStreamSSLCertificates(currentRead: SwiftAsyncSpecialPacket,
                                                         sslContext: SSLContext) throws {
        guard let valueArray = currentRead.tlsSettings.SSLCertificates else {
            return
        }

        let status = SSLSetCertificate(sslContext, valueArray as CFArray)
        guard status == noErr else {
            throw SwiftAsyncSocketError(msg: "Error in SSLSetCertificate")
        }
    }

    private func ssl_startTLSSetSwiftAsyncSocketSSLPeerID(currentRead: SwiftAsyncSpecialPacket,
                                                          sslContext: SSLContext) throws {
        guard let value = currentRead.tlsSettings.SSLPeerID else {
            return
        }

        let pointer: UnsafePointer<UInt8> = value.convert()

        let status = SSLSetPeerID(sslContext, pointer, value.count)

        guard status == noErr else {
            throw SwiftAsyncSocketError(msg: "Error in SSLSetPeerID")
        }
    }

    private func ssl_startTLSSetSwiftAsyncSocketSSLProtocolVersionMin(currentRead: SwiftAsyncSpecialPacket,
                                                                      sslContext: SSLContext) throws {
        guard let valueNumber = currentRead.tlsSettings.SSLProtocolVersionMin else {
            return
        }

        guard let minProtocol = SSLProtocol(rawValue: valueNumber),
            (minProtocol != SSLProtocol.sslProtocolUnknown) else {
            return
        }

        let status = SSLSetProtocolVersionMin(sslContext, minProtocol)
        guard status == noErr else {
            throw SwiftAsyncSocketError(msg: "Error in SSLSetProtocolVersionMin")
        }
    }

    private func ssl_startTLSSetSwiftAsyncSocketSSLProtocolVersionMax(currentRead: SwiftAsyncSpecialPacket,
                                                                      sslContext: SSLContext) throws {
        guard let valueNumber = currentRead.tlsSettings.SSLProtocolVersionMax else {
            return
        }

        guard let maxProtocol = SSLProtocol(rawValue: valueNumber),
            (maxProtocol != SSLProtocol.sslProtocolUnknown) else {
            return
        }

        let status = SSLSetProtocolVersionMax(sslContext, maxProtocol)
        guard status == noErr else {
            throw SwiftAsyncSocketError(msg: "Error in SSLSetProtocolVersionMax")
        }
    }

    private func ssl_startTLSSetSSLSessionOptionFalseStart(currentRead: SwiftAsyncSpecialPacket,
                                                           sslContext: SSLContext) throws {
        guard let valueBool = currentRead.tlsSettings.SSLSessionOptionFalseStart else {
            return
        }

        let status = SSLSetSessionOption(sslContext, .falseStart, valueBool)

        guard status == noErr else {
            throw SwiftAsyncSocketError(msg: "Error in SSLSessionOptionFalseStart")
        }
    }

    private func ssl_startTLSSetSSLSessionOptionSendOneByteRecord(currentRead: SwiftAsyncSpecialPacket,
                                                                  sslContext: SSLContext) throws {
        guard let valueBool = currentRead.tlsSettings.SSLSessionOptionSendOneByteRecord else {
            return
        }

        let status = SSLSetSessionOption(sslContext, .sendOneByteRecord, valueBool)

        guard status == noErr else {
            throw SwiftAsyncSocketError(msg: "Error in SSLSessionOptionSendOneByteRecord")
        }
    }

    private func ssl_startTLSSetSSLCipherSuites(currentRead: SwiftAsyncSpecialPacket,
                                                sslContext: SSLContext) throws {
        guard var ciphers = currentRead.tlsSettings.SSLCipherSuites else {
            return
        }

        let status = Security.SSLSetEnabledCiphers(sslContext, &ciphers, ciphers.count)

        guard status == noErr else {
            throw SwiftAsyncSocketError(msg: "Error in SSLSetEnabledCiphers")
        }
    }
    #if !os(iOS)
    private func ssl_startTLSSetSSLDiffieHellmanParameters(currentRead: SwiftAsyncSpecialPacket,
                                                           sslContext: SSLContext) throws {
        guard let valueData = currentRead.tlsSettings.SSLDiffieHellmanParameters else {
            return
        }

        let pointer: UnsafePointer<UInt8> = valueData.convert()

        let status = SSLSetDiffieHellmanParams(sslContext, pointer, valueData.count)

        guard status == noErr else {
            throw SwiftAsyncSocketError(msg:
                "Invalid value for SwiftAsyncSocketSSLDiffieHellmanParameters.")
        }
    }
    #endif
}
