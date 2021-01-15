//
//  ds4macosApp.swift
//  ds4macos
//

import SwiftUI
import GameController
import Network

@main
class ds4macosApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(gameControllerInfo: self.controllerService!.gameControllerInfo, selection: "controller")
                .onDisappear(perform: {
                    self.shutdown()
                })
                .environmentObject(self.dsuServer!)
                .environmentObject(self.controllerService!)
                .environmentObject(self.dsuServer!.clientsViewModel)
        }
    }
    
    var dsuServer: DSUServer?
    var controllerService: ControllerService?
    
    required init() {
        self.dsuServer = DSUServer()
        self.controllerService = ControllerService(server: self.dsuServer!)
        self.dsuServer!.setControllerService(controllerService: self.controllerService!)
        self.dsuServer!.startServer()
    }
    
    func shutdown() {
        self.dsuServer?.stopServer()
        exit(0)
    }
    
}
