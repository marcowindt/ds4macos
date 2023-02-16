//
//  SwiftAsyncSocket+ReadingDataPrivate.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2018/12/19.
//  Copyright © 2018 chouheiwa. All rights reserved.
//

import Foundation

extension SwiftAsyncSocket {
    func doReadDataAllReadFunction(bytesRead: inout Int,
                                   waiting: inout Bool,
                                   socketEOF: inout Bool,
                                   readIntoPreBuffer: inout Bool,
                                   estimatedBytesAvailable: Int) throws -> UnsafeMutablePointer<UInt8> {
        var buffer: UnsafeMutablePointer<UInt8>

        if flags.contains(.isSecure) {
            if isUsingCFStreamForTLS {
                #if os(iOS)
                buffer = try doReadDataCFReading(bytesRead: &bytesRead,
                                                 waiting: &waiting,
                                                 socketEOF: &socketEOF,
                                                 readIntoPreBuffer: &readIntoPreBuffer)
                #else
                fatalError("Code can not run here")
                #endif
            } else {
                buffer = try commonTLSReading(readIntoPreBuffer: &readIntoPreBuffer,
                                              estimatedBytesAvailable: estimatedBytesAvailable,
                                              waiting: &waiting,
                                              socketEOF: &socketEOF,
                                              bytesRead: &bytesRead)
            }
        } else {
            // Normal socket operation
            buffer = try normalSocketReadOperation(estimatedBytesAvailable: estimatedBytesAvailable,
                                                   waiting: &waiting,
                                                   socketEOF: &socketEOF,
                                                   bytesRead: &bytesRead,
                                                   readIntoPreBuffer: &readIntoPreBuffer)
        }

        return buffer
    }

    private func readIntoPreBufferDo(bytesToRead: UInt,
                                     readIntoPreBuffer: Bool,
                                     currentRead: SwiftAsyncReadPacket) -> UnsafeMutablePointer<UInt8> {
        // Make sure we have enough room in the buffer for our read.
        //
        // We are either reading directly into the currentRead->buffer,
        // or we're reading into the temporary preBuffer.
        if readIntoPreBuffer {
            preBuffer.ensureCapacityForWrite(capacity: size_t(bytesToRead))

            return preBuffer.writePointer
        } else {
            currentRead.ensureCapacity(for: bytesToRead)

            let length = Int(currentRead.startOffset + currentRead.bytesDone)

            return currentRead.buffer.convertMutable(offset: length)
        }
    }

    private func normalSocketReadOperation(estimatedBytesAvailable: Int,
                                           waiting: inout Bool,
                                           socketEOF: inout Bool,
                                           bytesRead: inout Int,
                                           readIntoPreBuffer: inout Bool) throws -> UnsafeMutablePointer<UInt8> {
        guard let currentRead = currentRead as? SwiftAsyncReadPacket else { fatalError("Logic Error") }

        var bytesToRead: UInt

        if currentRead.terminatorData != nil {
            let hint = UInt(estimatedBytesAvailable)

            (bytesToRead, readIntoPreBuffer) = currentRead.readLengthForTerminator(hint: hint)
        } else {
            bytesToRead = currentRead.readLength(for: UInt(estimatedBytesAvailable))
        }

        bytesToRead = min(bytesToRead, SIZE_MAX)

        let buffer = readIntoPreBufferDo(bytesToRead: bytesToRead,
                                         readIntoPreBuffer: readIntoPreBuffer,
                                         currentRead: currentRead)

        let result = Darwin.read(currentSocketFD, buffer, Int(bytesToRead))

        if result < 0 {
            if errno == EWOULDBLOCK {
                waiting = true
            } else {
                throw SwiftAsyncSocketError(msg: "Error in read() function")
            }
        } else if result == 0 {
            socketEOF = true
            socketFDBytesAvailable = 0
        } else {
            bytesRead = result

            if bytesRead < bytesToRead {
                // The read returned less data than requested.
                // This means socketFDBytesAvailable was a bit off due to timing,
                // because we read from the socket right when the readSource event was firing.
                socketFDBytesAvailable = 0
            } else {
                if socketFDBytesAvailable <= bytesRead {
                    socketFDBytesAvailable = 0
                } else {
                    socketFDBytesAvailable -= UInt(bytesRead)
                }
                if socketFDBytesAvailable == 0 {
                    waiting = true
                }
            }
        }
        return buffer
    }

    private func commonTLSReading(readIntoPreBuffer: inout Bool,
                                  estimatedBytesAvailable: Int,
                                  waiting: inout Bool,
                                  socketEOF: inout Bool,
                                  bytesRead: inout Int) throws -> UnsafeMutablePointer<UInt8> {
        guard let sslContext = sslContext,
            let currentRead = currentRead as? SwiftAsyncReadPacket
            else {assert(false, "Logic Error");fatalError("Logic Error")}
        // Using SecureTransport for TLS
        //
        // We know:
        // - how many bytes are available on the socket
        // - how many encrypted bytes are sitting in the sslPreBuffer
        // - how many decypted bytes are sitting in the sslContext
        //
        // But we do NOT know:
        // - how many encypted bytes are sitting in the sslContext
        //
        // So we play the regular game of using an upper bound instead.
        var defaultReadLength = (1024 * 32)

        if defaultReadLength < estimatedBytesAvailable {
            defaultReadLength = estimatedBytesAvailable + (1024 * 16)
        }
        var bytesToRead: UInt = 0

        (bytesToRead, readIntoPreBuffer) = currentRead.optimalReadLength(with: UInt(defaultReadLength))
        bytesRead = min(Int.max, bytesRead)

        // Make sure we have enough room in the buffer for our read.
        //
        // We are either reading directly into the currentRead->buffer,
        // or we're reading into the temporary preBuffer.

        let buffer = readIntoPreBufferDo(bytesToRead: bytesToRead,
                                         readIntoPreBuffer: readIntoPreBuffer,
                                         currentRead: currentRead)

        var result: OSStatus

        repeat {
            let loopBuffer = buffer + bytesRead

            let loopBytesToRead = size_t(bytesToRead) - bytesRead

            var loopBytesRead = 0

            result = SSLRead(sslContext, loopBuffer, loopBytesToRead, &loopBytesRead)

            bytesRead += loopBytesRead
        }while result == noErr && (bytesRead < bytesToRead)

        if result != noErr {
            switch result {
            case errSSLWouldBlock:
                waiting = true
            case errSSLClosedGraceful, errSSLClosedAbort:
                // We've reached the end of the stream.
                // Handle this the same way we would an EOF from the socket.
                socketEOF = true
                sslErrCode = result
            default:
                throw SwiftAsyncSocketError.sslError(code: result)
            }
            // It's possible that bytesRead > 0, even if the result was errSSLWouldBlock.
            // This happens when the SSLRead function is able to read some data,
            // but not the entire amount we requested.
            bytesRead = max(bytesRead, 0)
        }

        return buffer
    }

    #if os(iOS)
    private func doReadDataCFReading(bytesRead: inout Int,
                                     waiting: inout Bool,
                                     socketEOF: inout Bool,
                                     readIntoPreBuffer: inout Bool) throws -> UnsafeMutablePointer<UInt8> {
        guard let currentRead = currentRead as? SwiftAsyncReadPacket else {
            fatalError("Invalid logic")
        }

        let defaultReadLength = (1024 * 32)

        var bytesToRead: UInt = 0

        (bytesToRead, readIntoPreBuffer) = currentRead.optimalReadLength(with: UInt(defaultReadLength))

        let buffer = readIntoPreBufferDo(bytesToRead: bytesToRead,
                                         readIntoPreBuffer: readIntoPreBuffer,
                                         currentRead: currentRead)

        let result = CFReadStreamRead(readStream, buffer, CFIndex(bytesToRead))

        if result < 0 {
            guard let cfError = CFReadStreamCopyError(readStream) else {
                assert(false, "logic error")
                fatalError("logic error")
            }

            throw SwiftAsyncSocketError.cfError(error: cfError)
        } else if result == 0 {
            socketEOF = true
        } else {
            waiting = true
            bytesRead = result
        }

        // We only know how many decrypted bytes were read.
        // The actual number of bytes read was likely more due to the overhead of the encryption.
        // So we reset our flag, and rely on the next callback to alert us of more data.
        flags.remove(.secureSocketHasBytesAvailable)

        return buffer

    }
    #endif
}
