//
//  ClientsViewModel.swift
//  ds4macos
//

import Foundation

class ClientsViewModel: ObservableObject {
    @Published var clients: [String: Client] = [:]
    
}
