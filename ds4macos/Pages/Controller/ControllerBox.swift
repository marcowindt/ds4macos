//
//  ControllerView.swift
//  ds4macos
//

import Foundation
import SwiftUI


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
                Text("\(dsuController.slot)").font(.title)
            }.padding(10)
        }
    }
    
}
