//
//  ConnectedClient.swift
//  ds4macos
//

import Foundation
import SwiftUI

struct ConnectedClient: View {
    var client: Client

    var body: some View {
        GroupBox {
            HStack {
                Text("🟢").font(.subheadline)
                VStack(alignment: .leading) {
                    Text(self.client.getViewValue()).font(.subheadline)
                }
                Spacer()
                Text("Slots").font(.subheadline)
                
                HStack {
                    ForEach( Array(zip(self.client.slots.indices, self.client.slots)), id: \.0) { index, item in
                        Image(systemName: "\(index).square\(item ? ".fill" : "")").font(.subheadline)
                    }
                }
                
            }.padding(EdgeInsets(top: 5.0, leading: 10.0, bottom: 5.0, trailing: 10.0))
        }
    }
    
}

