//
//  ds4macosApp.swift
//  ds4macos
//

import SwiftUI
import GameController
import Network

@main
class ds4macosApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(gameControllerInfo: self.gameControllerInfo, selection: "controller")
                .onDisappear(perform: {
                    exit(0)
                })
        }
    }
    
    @ObservedObject var gameControllerInfo = ControllerInfo()
    var gameController: GCController!
    var counter: UInt32 = 0
    
    var prevMotion: GCMotion?
    
    var server: NWListener?
    @State var portUDP: NWEndpoint.Port = 26760
    
    var backgroundQueueUdpListener = DispatchQueue(label: "udp-lis.bg.queue", attributes: [])
    var backgroundQueueUdpConnection = DispatchQueue(label: "udp-con.bg.queue", attributes: [])
    
    var clients = [NWConnection]()
    
    required init() {
        startServer()
        observeControllers()
        
        
    }
    
    func observeControllers() {
        NotificationCenter.default.addObserver(self, selector: #selector(connectControllers), name: NSNotification.Name.GCControllerDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(disconnectControllers), name: NSNotification.Name.GCControllerDidDisconnect, object: nil)
    }
    
    @objc func connectControllers() {
        print(GCController.controllers().count)
        self.gameController = GCController.controllers().first!
        self.gameControllerInfo.info = "Connected: [vendor: \(self.gameController.vendorName!), productCategory: \(self.gameController.productCategory)]"
        print(self.gameControllerInfo.info)
        
        self.gameController.extendedGamepad!.valueChangedHandler = inputValueChange
        self.gameController.motion!.sensorsActive = true
        self.gameController.motion!.valueChangedHandler = motionValueChange
        print("Motion Sensor Enabled: \(self.gameController.motion!.sensorsActive)")
        self.prevMotion = self.gameController.motion!
    }
    
    @objc func disconnectControllers() {
        self.gameController = nil
        self.gameControllerInfo.info = "No controller connected"
        print("No controller connected")
    }
    
    func inputValueChange(gamePad: GCExtendedGamepad, element: GCControllerElement) {
        report()
    }
    
    func motionValueChange(motion: GCMotion) {
        report()
        self.prevMotion = motion
    }
    
    func startServer() {
        do {
            self.server = try NWListener(using: .udp, on: portUDP)
            
            self.server?.stateUpdateHandler = { (listenerState) in
                print("👂🏼👂🏼👂🏼 NWListener Handler called")
                switch listenerState {
                    case .setup:
                        print("Listener: Setup")
                    case .waiting(let error):
                        print("Listener: Waiting \(error)")
                    case .ready:
                        print("Listener: ✅ Ready and listens on port: \(self.server?.port?.debugDescription ?? "-")")
                    case .failed(let error):
                        print("Listener: Failed \(error)")
                    case .cancelled:
                        print("Listener: 🛑 Cancelled by myOffButton")
                    default:
                        break;
                }
            }

            self.server?.start(queue: .global())
            self.server?.newConnectionHandler = { (incomingUdpConnection) in
                print("📞📞📞 NWConnection Handler called ")
                incomingUdpConnection.stateUpdateHandler = { (udpConnectionState) in

                    switch udpConnectionState {
                    case .setup:
                        print("Connection: 👨🏼‍💻 setup")
                    case .waiting(let error):
                        print("Connection: ⏰ waiting: \(error)")
                    case .ready:
                        print("Connection: ✅ ready")
                        self.clients.append(incomingUdpConnection)
                        self.handleIncoming(incomingUdpConnection)
                        
                    case .failed(let error):
                        print("Connection: 🔥 failed: \(error)")
                    case .cancelled:
                        print("Connection: 🛑 cancelled")
                    default:
                        break
                    }
                }

                incomingUdpConnection.start(queue: .global())
            }
        
        } catch {
            print("Could not isten for incoming udp")
        }
    }
    
    func handleIncoming(_ incomingConnection: NWConnection) {
        incomingConnection.receiveMessage(completion: {(data, context, isComplete, error) in
            
            if let data = data, !data.isEmpty {
                let data = [UInt8](data)
                let type = [UInt8](data[16...19])
                
                if type == DSUMessage.TYPE_PORTS {
                    print("Received: Message Type: PORTS")
                    self.handleIncomingPortsRequest(connection: incomingConnection, data: data)
                } else if type == DSUMessage.TYPE_DATA {
                    print("Received: Message Type: DATA")
                    self.handleIncomingDataRequest(connection: incomingConnection, data: data)
                } else if type == DSUMessage.TYPE_VERSION {
                    print("Message Type: VERSION")
                } else {
                    print("Uknown message type")
                }
            }
            
            if error == nil {
//                self.handleIncoming(incomingConnection)
            }
        })
        
    }
    
    func handleIncomingPortsRequest(connection: NWConnection, data: [UInt8]) {
        let requestsCount = data[20]
        
        for i in 0..<requestsCount {
            let dataMessage = self.getPortsPacket(index: i)
            self.sendDataToClient(client: connection, data: Data(dataMessage))
        }
    }
    
    func handleIncomingDataRequest(connection: NWConnection, data: [UInt8]) {
        let flags = data[24]
        let regId = data[25]
        
        if flags == 0 && regId == 0 {
            report()
        }
    }
    
    func getPortsPacket(index: UInt8) -> [UInt8] {
        if self.gameController != nil && index == 0 {
            let dsuController = DSUController(gameController: self.gameController, slot: 0, counter: 0, prevMotion: self.prevMotion!)
            return DSUMessage.make(type: DSUMessage.TYPE_PORTS, data: dsuController.getInfoPacket())
        }
        return DSUMessage.make(type: DSUMessage.TYPE_PORTS, data: DSUController.defaultInfoPacket(index: index))
    }
    
    func report() {
        if self.gameController != nil {
            let dsuController: DSUController = DSUController(gameController: self.gameController, slot: 0, counter: self.counter, prevMotion: self.prevMotion!)
            self.sendDataToClients(data: Data(dsuController.getDataPacket()))
            self.counter += 1
        } else {
            print("Error cannot report, since no controller is currently connected (which is weird since this func is only called when there is one connected)")
        }
    }
    
    func sendDataToClients(data: Data) {
//        print("number of clients: \(self.clients.count)")
        for client in self.clients {
            self.sendDataToClient(client: client, data: data)
        }
    }
    
    func sendDataToClient(client: NWConnection, data: Data) {
        client.send(content: data, completion: NWConnection.SendCompletion.contentProcessed({ (error: NWError?) in
            if error != nil {
                // Client disconnect?
                self.clients.removeAll { (connection) -> Bool in
                    return connection.endpoint.hashValue == client.endpoint.hashValue
                }
                client.cancel()
                print("Got an error sending controller data: \(error!), \(self.clients.count)")
            }
        }))
    }
    
}

extension Data {
    struct HexEncodingOptions: OptionSet {
        let rawValue: Int
        static let upperCase = HexEncodingOptions(rawValue: 1 << 0)
    }

    func hexEncodedString(options: HexEncodingOptions = []) -> String {
        let format = options.contains(.upperCase) ? "%02hhX" : "%02hhx"
        return map { String(format: format, $0) }.joined()
    }
}

extension GCMotion {
    
    func vecAccelerometerDiff(motion: GCMotion) -> [Double] {
        return [abs(self.acceleration.x - motion.acceleration.x),
                abs(self.acceleration.y - motion.acceleration.y),
                abs(self.acceleration.z - motion.acceleration.z)]
    }
    
    func vecGyroDiff(motion: GCMotion) -> [Double] {
        return [abs(self.rotationRate.x - motion.rotationRate.x),
                abs(self.rotationRate.y - motion.rotationRate.y),
                abs(self.rotationRate.z - motion.rotationRate.z)]
    }
    
    func outBounds(motion: GCMotion) -> Bool {
        let gyroBound = 0.0001
        let accBound = 0.001
        let vecAccDiff = self.vecAccelerometerDiff(motion: motion)
        let vecGyroDiff = self.vecGyroDiff(motion: motion)
        
        return vecGyroDiff[0] > gyroBound || vecGyroDiff[1] > gyroBound || vecGyroDiff[2] > gyroBound
    }
    
}

