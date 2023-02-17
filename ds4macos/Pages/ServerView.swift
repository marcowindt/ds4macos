//
//  ServerView.swift
//  ds4macos
//

import Foundation
import SwiftUI
import Combine

struct ServerView: View {
    @EnvironmentObject var serverViewModel: ServerViewModel
    @EnvironmentObject var clientsViewModel: ClientsViewModel
    @State private var showAlert: Bool = false

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                HStack {
                    Text("Server")
                        .font(.title)
                }
                VStack(alignment: .leading) {
                    if self.serverViewModel.isRunning {
                        Text("Server is running")
                    } else {
                        Text("Server stopped")
                    }
                }
                GroupBox {
                    VStack {
                        HStack(spacing: 10) {
                            Text("IP Address").frame(width: 100, alignment: .leading)
                            TextField("IP Address", text: $serverViewModel.ipAddress).disabled(true)
                        }
                        HStack(spacing: 10) {
                            Text("Port").frame(width: 100, alignment: .leading)
                            TextField("port number", text: $serverViewModel.portUDP)
                                .onReceive(serverViewModel.$portUDP) { typedValue in
                                    if let newValue = Int(typedValue) {
                                        self.serverViewModel.dsuServer.setPort(number: newValue.description)
                                    } else {
                                        self.serverViewModel.dsuServer.setPort(number: serverViewModel.portUDP)
                                    }
                                }.disabled(self.serverViewModel.isRunning)
                        }
                    }.padding(10)
                }
                
                if self.clientsViewModel.clients.count > 0 {
                    Divider()
                    Text("\(self.clientsViewModel.clients.count) client(s) connected")
                    VStack {
                        ForEach(self.clientsViewModel.clients.keys.sorted(by: >), id: \.self) { (key: String) in
                            ConnectedClient(client: self.clientsViewModel.clients[key]!)
                        }
                    }
                }
                
                Divider()
                
                if self.serverViewModel.isRunning {
                    Button("Stop server") {
                        self.serverViewModel.dsuServer.stopServer()
                    }
                } else {
                    Button("Start server") {
                        let portValue = Int(self.serverViewModel.portUDP) ?? 0
                        if portValue > 1 && portValue < 65355 {
                            self.serverViewModel.dsuServer.setPort(number: portValue.description)
                            self.serverViewModel.dsuServer.startServer()
                        } else {
                            self.showAlert = true
                        }
                    }
                }
                Spacer()
            }.alert(isPresented: $showAlert, content: {
                Alert(title: Text("Cannot start server"), message: Text("Port number is invalid"), dismissButton: .default(Text("Got it!")))
            })
            Spacer()
        }.padding()
    }
}
