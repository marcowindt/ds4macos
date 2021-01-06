//
//  SettingsView.swift
//  ds4macos
//

import Foundation
import SwiftUI

struct SettingsView: View {

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Settings")
                    .font(.title)
                Text("Accelerometer")
                Text("Gyroscope")
                Divider()
                Text("STILL TODO")
                Spacer()
            }
            Spacer()
        }.padding()
    }
}
