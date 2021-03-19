//
//  ds4macosApp.swift
//  ds4macos
//

import SwiftUI
import GameController
import Network

struct AppView: View {
    var dsuServer: DSUServer?
    var controllerService: ControllerService?
    
    var body: some View {
        ContentView(gameControllerInfo: self.controllerService!.gameControllerInfo, selection: "controller")
            .environmentObject(self.dsuServer!)
            .environmentObject(self.controllerService!)
            .environmentObject(self.dsuServer!.clientsViewModel)
            .onDisappear {
                self.shutdown()
            }
    }
    
    func shutdown() {
        self.dsuServer?.stopServer()
        exit(0)
    }

}
