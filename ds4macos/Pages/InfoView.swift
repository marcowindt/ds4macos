//
//  InfoView.swift
//  ds4macos
//

import Foundation
import SwiftUI
import GameController

struct InfoView: View {
    @ObservedObject var gameControllerInfo: ControllerInfo

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Info")
                    .font(.title)
                Text(self.gameControllerInfo.info)
                Text("Only one controller at once at the moment")
                Divider()
                Text("STILL TODO")
                Spacer()
            }
            Spacer()
        }.padding()
    }
}
