//
//  ds4iosApp.swift
//  ds4ios
//
//  Created by Marco Dijkslag on 22/02/2023.
//

import SwiftUI

@main
class ds4iosApp: App {
    var activity: NSObjectProtocol?
    
    var body: some Scene {
        WindowGroup {
            ContentView(gameControllerInfo: self.controllerService!.gameControllerInfo, selection: "controller")
                .onDisappear(perform: {
                    self.shutdown()
                })
                .environmentObject(self.controllerService!)
                .environmentObject(self.dsuServer!.clientsViewModel)
                .environmentObject(self.dsuServer!.serverViewModel!)
        }
    }
    
    var dsuServer: DSUServer?
    var controllerService: ControllerService?
    
    required init() {
        self.activity = ProcessInfo.processInfo.beginActivity(options: .userInitiatedAllowingIdleSystemSleep, reason: "ds4macos UDP server")
        
        self.dsuServer = DSUServer()
        self.controllerService = ControllerService(server: self.dsuServer!)
        self.dsuServer!.setControllerService(controllerService: self.controllerService!)
        self.dsuServer!.setServerViewModel(serverViewModel: ServerViewModel(dsuServer: self.dsuServer!))
        self.dsuServer!.startServer()
    }
    
    func shutdown() {
        self.dsuServer?.stopServer()
        exit(0)
    }
}
