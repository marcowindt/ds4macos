//
//  AppDelegate.swift
//  ds4macos(for not big sur)
//

import Cocoa
import SwiftUI

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    var window: NSWindow!
    
    var dsuServer: DSUServer?
    var controllerService: ControllerService?
    
    override init() {
        self.dsuServer = DSUServer()
        self.controllerService = ControllerService(server: self.dsuServer!)
        self.dsuServer!.setControllerService(controllerService: self.controllerService!)
        self.dsuServer!.startServer()
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        print("did finish launching")
        // Create the SwiftUI view that provides the window contents.
        let contentView = AppView(dsuServer: self.dsuServer, controllerService: self.controllerService)

        // Create the window and set the content view.
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.isReleasedWhenClosed = true
        window.center()
        window.setFrameAutosaveName("Main Window")
        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
        shutdown()
    }
    
    func shutdown() {
        self.dsuServer?.stopServer()
        exit(0)
    }


}
