//
//  ServerView.swift
//  ds4macos
//

import Foundation
import SwiftUI
import Combine

struct ServerView: View {
    @EnvironmentObject var server: DSUServer
    @State var portNum: String = "26760"
    @State var ipAddress: String = "127.0.0.1"
    @State private var showAlert: Bool = false

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                HStack {
                    Text("Server")
                        .font(.title)
                }
                VStack(alignment: .leading) {
                    if self.server.isRunning {
                        Text("Server is running")
                    } else {
                        Text("Server stopped")
                    }
                }
                GroupBox {
                    VStack {
                        HStack(spacing: 10) {
                            Text("IP Address").frame(width: 100, alignment: .leading)
                            TextField("IP Address", text: $ipAddress).disabled(true)
                        }
                        HStack(spacing: 10) {
                            Text("Port").frame(width: 100, alignment: .leading)
                            TextField("port number", text: $portNum)
                                .onReceive(Just(portNum)) { typedValue in
                                    if let newValue = Int(typedValue) {
                                        self.portNum = newValue.description
                                    } else {
                                        self.portNum = "26760"
                                    }
                                }.disabled(self.server.isRunning)
                        }
                    }.padding(10)
                }
                Divider()
                
                if self.server.isRunning {
                    Button("Stop server") {
                        self.server.stopServer()
                    }
                } else {
                    Button("Start server") {
                        let portValue = Int(self.portNum) ?? 0
                        if portValue > 1 && portValue < 65355 {
                            self.server.setPort(number: portValue.description)
                            self.server.startServer()
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
