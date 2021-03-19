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
                NavigationLink(
                    destination: ControllersView()
                ) {
                    Text("🎮 Controllers")
                }.tag("controllers")
                NavigationLink(
                    destination: ServerView()
                ) {
                    Text("🌐 Server")
                }.tag("server")
                NavigationLink(
                    destination: SettingsView()
                ) {
                    Text("⚙️ Settings")
                }.tag("settings")
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

