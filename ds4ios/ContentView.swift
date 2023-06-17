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
                NavigationLink(destination: ControllersView()) {
                    HStack {
                        Image(systemName: "gamecontroller").font(.subheadline)
                        Text("Controllers")
                    }
                }.tag("controllers")
                NavigationLink(destination: ServerView()) {
                                        Text("Server")
                }.tag("server")
//                Label("Controllers", systemImage: "gamecontroller")
//                    .tag("controllers")
                
//                Divider()

//                Label("Server", systemImage: "network")
//                    .tag("server")
                
                // Label("Settings", systemImage: "gear")
                //    .tag("settings")
            }
//            .listStyle(PlainListStyle())
            
            if self.selection == "server" {
                ServerView()
            } else if self.selection == "settings" {
                SettingsView()
            } else {
                ControllersView()
            }
            
        }
//        .frame(minWidth: 400, minHeight: 250)
        .environmentObject(gameControllerInfo)
    }
}

