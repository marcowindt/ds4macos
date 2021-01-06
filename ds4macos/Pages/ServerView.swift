//
//  ServerView.swift
//  ds4macos
//

import Foundation
import SwiftUI

struct ServerView: View {

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Server")
                    .font(.title)
                Text("Status: Running (automatically on startup)")
                Text("IP: Your mac's ip address")
                Text("Port: 26760")
                Divider()
                Text("STILL TODO")
                Spacer()
            }
            Spacer()
        }.padding()
    }
}
