//
//  ContentView.swift
//  ds4macos
//

import SwiftUI
import GameController

struct ContentView: View {
    @ObservedObject var gameControllerInfo: ControllerInfo
    @State var selection: String? = "info"
    
    var body: some View {
        NavigationView {
            List(selection: self.$selection) {
                Label("Info", systemImage: "info")
                    .tag("info")
                Label("Server", systemImage: "largecircle.fill.circle")
                    .tag("server")
                
                Divider()
                
                Label("Settings", systemImage: "gear")
                    .tag("settings")
            }
            .listStyle(SidebarListStyle())
            .frame(minWidth: 100, idealWidth: 150, maxWidth: 200, maxHeight: .infinity)
            
            if self.selection == "server" {
                ServerView()
            } else if self.selection == "settings" {
                SettingsView()
            } else {
                InfoView(gameControllerInfo: self.gameControllerInfo)
            }
            
        }
        .frame(minWidth: 400, minHeight: 250)
    }
}

