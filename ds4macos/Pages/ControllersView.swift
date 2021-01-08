//
//  InfoView.swift
//  ds4macos
//

import Foundation
import SwiftUI
import GameController

struct ControllersView: View {
    @EnvironmentObject var controllerService: ControllerService

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Controllers")
                    .font(.title)
                
                if self.controllerService.numberOfControllersConnected > 0 {
                    VStack {
                        ForEach(self.controllerService.connectedControllers.keys.sorted(by: >), id: \.self) { (key: Int) in
                            let controller = self.controllerService.connectedControllers[key]!
                            ControllerBox(dsuController: controller)
                        }
                    }
                } else {
                    Spacer()
                    HStack(alignment: .center) {
                        Spacer()
                        Text("No controllers connected")
                        Spacer()
                    }
                }
                Spacer()
                Divider()
                Text("Connected controllers: \(self.controllerService.numberOfControllersConnected) of \(self.controllerService.maximumControllerCount)")
                    .font(.subheadline)
            }
            Spacer()
        }.padding()
    }
}
