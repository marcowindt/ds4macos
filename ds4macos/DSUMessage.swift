//
//  DSUMessage.swift
//  ds4macos
//

import Foundation
import zlib


class DSUMessage {
    
    static let TYPE_VERSION: [UInt8] = [0x00, 0x00, 0x10, 0x00]
    static let TYPE_PORTS: [UInt8] = [0x01, 0x00, 0x10, 0x00]
    static let TYPE_DATA: [UInt8] = [0x02, 0x00, 0x10, 0x00]
    
    static func make(type: [UInt8], data: [UInt8]) -> [UInt8] {
        let packetLength: UInt8 = UInt8(data.count + 4)
        
        var packet: [UInt8] = [
            0x44, 0x53, 0x55, 0x53,           // DSUS
            0xE9, 0x03,                       // Protocol version (1001)
            (packetLength),            // Data length (Little endian)
            (packetLength >> 8),       // Data length
            0x00, 0x00, 0x00, 0x00,           // CRC32 initially empty
            0xEF, 0xEF, 0xEF, 0xEF,           // Server ID
        ]
        
        packet.append(contentsOf: type)
        packet.append(contentsOf: data)
        
        let packetCrc = UInt32(crc32(0, packet, UInt32(packet.count)))
        
        packet[8] = UInt8(packetCrc & 0xFF)
        packet[9] = UInt8((packetCrc >> 8) & 0xFF)
        packet[10] = UInt8((packetCrc >> 16) & 0xFF)
        packet[11] = UInt8((packetCrc >> 24) & 0xFF)
        
        return packet
    }
    
}
