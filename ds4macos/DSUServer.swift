//
//  DSUServer.swift
//  ds4macos
//

import Foundation
import Network


class DSUServer: ObservableObject {
    
    var server: NWListener?
    @Published var portUDP: NWEndpoint.Port = 26760
    @Published var ipAddress: String = "127.0.0.1"
    
    @Published var isRunning: Bool = false
    
    var backgroundQueueUdpListener = DispatchQueue(label: "udp-lis.bg.queue", attributes: [])
    var backgroundQueueUdpConnection = DispatchQueue(label: "udp-con.bg.queue", attributes: [])
    
    var clients = [NWConnection]()
    
    var counter: UInt32 = 0
    
    var controllerService: ControllerService?
    
    init() {
        
    }
    
    func setControllerService(controllerService: ControllerService) {
        self.controllerService = controllerService
    }
    
    func startServer() {
        do {
            self.server = try NWListener(using: .udp, on: portUDP)
            
            self.server?.stateUpdateHandler = self.serverStateUpdateHandler
            self.server?.newConnectionHandler = self.serverNewConnectionHandler
            
            self.server?.start(queue: .global())
            self.isRunning = true
        } catch {
            self.isRunning = false
            print("Could not isten for incoming udp")
        }
    }
    
    func stopServer() {
        self.server?.cancel()
        self.server = nil
        self.isRunning = false
    }
    
    func setPort(number: String) {
        if self.isRunning == false {
            self.portUDP = NWEndpoint.Port(number)!
            print(self.portUDP)
        }
    }
    
    func serverStateUpdateHandler(listenerState: NWListener.State) {
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
    
    func serverNewConnectionHandler(newConnection: NWConnection) {
        print("📞📞📞 NWConnection Handler called ")
        newConnection.stateUpdateHandler = { (udpConnectionState) in

            switch udpConnectionState {
            case .setup:
                print("Connection: 👨🏼‍💻 setup")
            case .waiting(let error):
                print("Connection: ⏰ waiting: \(error)")
            case .ready:
                print("Connection: ✅ ready")
                self.clients.append(newConnection)
                self.handleIncoming(newConnection)
            case .failed(let error):
                print("Connection: 🔥 failed: \(error)")
            case .cancelled:
                print("Connection: 🛑 cancelled")
            default:
                break
            }
        }

        newConnection.start(queue: .global())
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
            if self.controllerService != nil {
                let dsuController = DSUController(gameController: self.controllerService!.gameController!, slot: 0, counter: 0)
                report(controller: dsuController)
            }
        }
    }
    
    func getPortsPacket(index: UInt8) -> [UInt8] {
        if self.controllerService != nil && index == 0 {
            let dsuController = DSUController(gameController: self.controllerService!.gameController!, slot: 0, counter: 0)
            return DSUMessage.make(type: DSUMessage.TYPE_PORTS, data: dsuController.getInfoPacket())
        }
        return DSUMessage.make(type: DSUMessage.TYPE_PORTS, data: DSUController.defaultInfoPacket(index: index))
    }
    
    func report(controller: DSUController) {
        self.sendDataToClients(data: Data(controller.getDataPacket()))
        self.counter += 1
    }
    
    func sendDataToClients(data: Data) {
        for client in self.clients {
            self.sendDataToClient(client: client, data: data)
        }
    }
    
    func sendDataToClient(client: NWConnection, data: Data) {
        if self.isRunning {
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
    
//    func getIPAddress() -> String {
//        var address: String?
//        var ifaddr: UnsafeMutablePointer<ifaddrs>? = nil
//        if getifaddrs(&ifaddr) == 0 {
//            var ptr = ifaddr
//            while ptr != nil {
//                defer { ptr = ptr?.pointee.ifa_next }
//
//                guard let interface = ptr?.pointee else { return "" }
//                let addrFamily = interface.ifa_addr.pointee.sa_family
//                if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
//
//                    // wifi = ["en0"]
//                    // wired = ["en2", "en3", "en4"]
//                    // cellular = ["pdp_ip0","pdp_ip1","pdp_ip2","pdp_ip3"]
//
//                    let name: String = String(cString: (interface.ifa_name))
//                    if  name == "en0" || name == "en2" || name == "en3" || name == "en4" || name == "pdp_ip0" || name == "pdp_ip1" || name == "pdp_ip2" || name == "pdp_ip3" {
//                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
//                        getnameinfo(interface.ifa_addr, socklen_t((interface.ifa_addr.pointee.sa_len)), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST)
//                        address = String(cString: hostname)
//                    }
//                }
//            }
//            freeifaddrs(ifaddr)
//        }
//        return address ?? ""
//    }
    
}
