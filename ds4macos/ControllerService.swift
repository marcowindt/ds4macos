//
//  ControllerService.swift
//  ds4macos
//
//  Created by Marco Dijkslag on 07/01/2021.
//

import Foundation
import GameController
import SwiftUI

class ControllerService: ObservableObject {
    
    @ObservedObject var gameControllerInfo = ControllerInfo()
    var gameController: GCController?
    var prevMotion: GCMotion?
    
    var numberOfControllersConnected = 0
    @Published var connectedControllers: [GCController] = []
    
    var server: DSUServer?
    
    init(server: DSUServer) {
        self.server = server
        self.observeControllers()
    }
    
    func observeControllers() {
        NotificationCenter.default.addObserver(self, selector: #selector(connectControllers), name: NSNotification.Name.GCControllerDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(disconnectControllers), name: NSNotification.Name.GCControllerDidDisconnect, object: nil)
    }
    
    @objc func connectControllers() {
        self.gameController = GCController.controllers().first!
        self.gameControllerInfo.info = "Connected: [vendor: \(self.gameController!.vendorName!), productCategory: \(self.gameController!.productCategory)]"
        print(self.gameControllerInfo.info)
        
        self.gameController!.extendedGamepad!.valueChangedHandler = inputValueChange
        self.gameController!.motion!.sensorsActive = true
        self.gameController!.motion!.valueChangedHandler = motionValueChange
        print("Motion Sensor Enabled: \(self.gameController!.motion!.sensorsActive)")
        self.prevMotion = self.gameController!.motion!
        self.numberOfControllersConnected += 1
        
        self.connectedControllers = GCController.controllers()
    }
    
    @objc func disconnectControllers() {
        self.gameController = nil
        self.gameControllerInfo.info = "No controller connected"
        print("No controller connected")
        self.numberOfControllersConnected -= 1
    }
    
    func inputValueChange(gamePad: GCExtendedGamepad, element: GCControllerElement) {
        let dsuController: DSUController = DSUController(gameController: self.gameController!, slot: 0, counter: self.server!.counter)
        self.server!.report(controller: dsuController)
    }
    
    func motionValueChange(motion: GCMotion) {
        let dsuController: DSUController = DSUController(gameController: self.gameController!, slot: 0, counter: self.server!.counter)
        self.server!.report(controller: dsuController)
        self.prevMotion = motion
    }
    
    
}
