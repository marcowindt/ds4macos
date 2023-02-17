//
//  ContentView.swift
//  ds4macos
//

import SwiftUI
import GameController

struct ContentView: View {
    @ObservedObject var gameControllerInfo: ControllerInfo
    @State var selection: String? = "controllers"
    
    var body: some View {
        NavigationView {
            List(selection: self.$selection) {
                Label("Controllers", systemImage: "gamecontroller")
                    .tag("controllers")
                
                Divider()

                Label("Server", systemImage: "network")
                    .tag("server")
                
                // Label("Settings", systemImage: "gear")
                //    .tag("settings")
            }
            .listStyle(SidebarListStyle())
            .frame(minWidth: 100, idealWidth: 150, maxWidth: 200, maxHeight: .infinity)
            
            if self.selection == "server" {
                ServerView()
            } else if self.selection == "settings" {
                SettingsView()
            } else {
                ControllersView()
            }
            
        }
        .frame(minWidth: 400, minHeight: 250)
        .environmentObject(gameControllerInfo)
    }
}

