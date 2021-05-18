//
//  ControllerService.swift
//  ds4macos
//
//  Created by Marco Dijkslag on 07/01/2021.
//

import Foundation
import GameController
import SwiftUI

@available(OSX 10.15, *)
class ControllerService: ObservableObject {
    
    let maximumControllerCount: Int
    
    @ObservedObject var gameControllerInfo = ControllerInfo()
    var prevMotion: GCMotion?
    
    @Published var numberOfControllersConnected = 0
    @Published var connectedControllers: [Int: DSUController] = [:]
    
    var server: DSUServer?
    
    init(server: DSUServer, maximumControllerCount: Int = 4) {
        self.maximumControllerCount = maximumControllerCount
        self.server = server
        self.observeControllers()
    }
    
    func reportControllers() {
        for dsuController in self.connectedControllers {
            self.server!.report(controller: dsuController.value)
        }
    }
    
    func reportController(dsuController: DSUController) {
        self.server!.report(controller: dsuController)
    }
    
    func observeControllers() {
        NotificationCenter.default.addObserver(self, selector: #selector(onControllerConnect), name: NSNotification.Name.GCControllerDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onControllerDisconnect), name: NSNotification.Name.GCControllerDidDisconnect, object: nil)
    }
    
    func firstFreeSlot() -> Int {
        for i in 0..<self.maximumControllerCount {
            if !self.connectedControllers.keys.contains(i) {
                return i
            }
        }
        return -1
    }
    
    @objc func onControllerConnect(_ notification: Notification) {
        guard self.connectedControllers.count < self.maximumControllerCount else { return }
        let controller = notification.object as! GCController
        let freeSlot = self.firstFreeSlot()
        if freeSlot != -1 {
            self.addControllerToSlots(controller: controller, slot: freeSlot)
        }
    }
    
    func addControllerToSlots(controller: GCController, slot: Int) {
        self.connectedControllers[slot] = DSUController(controllerService: self, gameController: controller, slot: UInt8(slot))
        self.gameControllerInfo.info = "Connected: [vendor: \(controller.vendorName ?? "?"), productCategory: \(controller.productCategory)]"
        print(self.gameControllerInfo.info)
        self.numberOfControllersConnected += 1
    }
    
    @objc func onControllerDisconnect(_ notification: Notification) {
        let controller = notification.object as! GCController
        print("Disconnected: [vendor: \(controller.vendorName ?? "?"), productCategory: \(controller.productCategory)]")
        self.removeControllerFromSlots(controller: controller)
    }
    
    func removeControllerFromSlots(controller: GCController) {
        var removeSlot: Int = -1
        for dsuController in self.connectedControllers {
            if dsuController.value.gameController == controller {
                removeSlot = Int(dsuController.value.slot)
                break
            }
        }
        if removeSlot != -1 {
            self.connectedControllers.removeValue(forKey: removeSlot)
        }
        self.numberOfControllersConnected -= 1
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.GCControllerDidConnect, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.GCControllerDidDisconnect, object: nil)
    }
    
    
}
