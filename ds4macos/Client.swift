//
//  Client.swift
//  ds4macos
//

import Foundation
import Network
import SwiftAsyncSocket

class Client {

    var slots: [Bool] = [false, false, false, false]

    var server: DSUServer
    var address: SwiftAsyncUDPSocketAddress
    var socket: SwiftAsyncUDPSocket
    var timeStampLastDataRequest: UInt64
    var port: UInt16
    
    let timeOut: UInt64 = 10 * 1000000

    init(server: DSUServer, socket: SwiftAsyncUDPSocket, address: SwiftAsyncUDPSocketAddress, port: UInt16) {
        self.server = server
        self.socket = socket
        self.timeStampLastDataRequest = UInt64(Date.init().timeIntervalSince1970 * 1000000)
        self.address = address
        self.port = port
    }
    
    func setTimeStampOnDataRequest() {
        self.timeStampLastDataRequest = UInt64(Date.init().timeIntervalSince1970 * 1000000)
    }

    func setSlot(slot: Int) {
        if slot >= 0 && slot < self.slots.count {
            self.slots[slot] = true
        }
    }
    
    func unsetSlot(slot: Int) {
        if slot >= 0 && slot < self.slots.count {
            self.slots[slot] = false
        }
    }
    
    func send(dataMessage: Data) {
        if (UInt64(Date.init().timeIntervalSince1970 * 1000000) - self.timeStampLastDataRequest) > self.timeOut {
            print("client timed out, removing from client list")
            self.close()
            return
        }
        do {
            try self.socket.send(data: dataMessage, address: self.address.address, tag: 10)
        } catch {
            self.close()
            print("could not send data to client")
        }
    }
    
    func close() {
        self.server.clients.removeValue(forKey: "\(self.address.host):\(self.address.port)")
        self.server.updateClientsViewModel()
    }
    
    func getViewValue() -> String {
        return "\(self.address.host):\(self.address.port)"
    }

}
