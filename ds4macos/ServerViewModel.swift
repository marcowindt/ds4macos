//
//  ServerViewModel.swift
//  ds4macos
//
//  Created by Marco Dijkslag on 17/02/2023.
//

import Foundation

class ServerViewModel: ObservableObject {
    @Published var portUDP: String = "26760"
    @Published var ipAddress: String = "localhost"
    @Published var isRunning: Bool = true
    
    let dsuServer: DSUServer
    
    init(dsuServer: DSUServer) {
        self.dsuServer = dsuServer
        self.portUDP = self.dsuServer.portUDP.description
        self.ipAddress = self.dsuServer.ipAddress
        self.isRunning = self.dsuServer.isRunning
    }
}
