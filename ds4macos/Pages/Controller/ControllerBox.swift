//
//  ControllerView.swift
//  ds4macos
//

import Foundation
import SwiftUI

@available(OSX 11.0, *)
struct ControllerBox: View {
    var dsuController: DSUController

    var body: some View {
        GroupBox {
            HStack {
                Text("🎮").font(.largeTitle)
                VStack(alignment: .leading) {
                    Text(dsuController.gameController!.vendorName!).font(.headline)
                    Text(dsuController.gameController!.productCategory).font(.subheadline)
                }
                Spacer()
                Text("Slot")
                Image(systemName: "\(dsuController.slot).square.fill").font(.title)
            }.padding(10)
        }
    }
    
}
