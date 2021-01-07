//
//  InfoView.swift
//  ds4macos
//

import Foundation
import SwiftUI
import GameController

struct InfoView: View {
    @EnvironmentObject var gameControllerInfo: ControllerInfo
    @EnvironmentObject var controllerService: ControllerService

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Info")
                    .font(.title)
                Text("Connected controllers: \(self.controllerService.numberOfControllersConnected)").font(.subheadline)
                VStack {
                    ForEach(self.controllerService.connectedControllers, id: \.hashValue) { controller in
                        GroupBox {
                            HStack {
                                Text("🎮").font(.largeTitle)
                                VStack(alignment: .leading) {
                                    Text((controller as GCController).vendorName!).font(.headline)
                                    Text((controller as GCController).productCategory).font(.subheadline)
                                }
                                Spacer()
                                Text("🟢").font(.title)
                            }.padding(10)
                        }
                    }
                }
                Divider()
                Text("Can only connect up to one controller at the moment")
                Text("STILL TODO")
                Spacer()
            }
            
            
            
            Spacer()
        }.padding()
    }
}
