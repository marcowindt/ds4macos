//
//  Client.swift
//  ds4macos
//

import Foundation
import Network

class Client {

    var slots: [Bool] = [false, false, false, false]

    var server: DSUServer
    var address: String
    var connection: NWConnection
    var timeStampLastDataRequest: UInt64
    
    let timeOut: UInt64 = 10 * 1000000

    init(server: DSUServer, connection: NWConnection, address: String) {
        self.server = server
        self.connection = connection
        self.timeStampLastDataRequest = UInt64(Date.init().timeIntervalSince1970 * 1000000)
        self.address = address
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
        self.connection.send(content: dataMessage, completion: NWConnection.SendCompletion.contentProcessed({ (error: NWError?) in
            if error != nil {
                // Client disconnect?
                print("Got an error sending controller data: \(error!)")
                self.close()
            }
        }))
    }
    
    func close() {
        self.connection.cancel()
        self.server.clients.removeValue(forKey: self.address)
        self.server.updateClientsViewModel()
    }

}
