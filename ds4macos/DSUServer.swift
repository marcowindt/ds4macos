//
//  DSUServer.swift
//  ds4macos
//

import Foundation
import Network
import SwiftAsyncSocket


class DSUServer: ObservableObject, SwiftAsyncUDPSocketDelegate {
    
    @Published var portUDP: UInt16 = 26760
    @Published var ipAddress: String = "localhost"
    
    let serverSocket: SwiftAsyncUDPSocket
    let port: UInt16 = 26760
    
    @Published var isRunning: Bool = false
    
    var backgroundQueueUdpListener = DispatchQueue(label: "udp-lis.bg.queue", attributes: [])
    var backgroundQueueUdpConnection = DispatchQueue(label: "udp-con.bg.queue", attributes: [])
    
    @Published var clientsViewModel: ClientsViewModel = ClientsViewModel()
    var clients: [String: Client] = [:]
    
    var counter: UInt32 = 0
    
    var controllerService: ControllerService?
    
    var didReceiveData: ((Data) -> Void)?
    
    init() {
        self.serverSocket = SwiftAsyncUDPSocket(delegate: nil, delegateQueue: self.backgroundQueueUdpListener)
    }
    
    func setControllerService(controllerService: ControllerService) {
        self.controllerService = controllerService
    }
    
    func startServer() {
        do {
            self.serverSocket.delegate = self
            try serverSocket.bind(to: "localhost", port: self.port)
            try serverSocket.receiveAlways()
            self.isRunning = true
            
            let queue = DispatchQueue(label: "report loop")
            queue.async {
                while self.isRunning == true {
                    self.controllerService?.reportControllers()
                    Thread.sleep(forTimeInterval: 0.001)
                }
                if (self.isRunning == false) {
                    print("server not running")
                    Thread.sleep(forTimeInterval: 1.0)
                }
            }
        } catch {
            self.isRunning = false
            print("Could not isten for incoming udp")
        }
    }
    
    func stopServer() {
        self.serverSocket.close()
        for (_, client) in self.clients {
            client.close()
        }
        self.isRunning = false
    }
    
    func setPort(number: String) {
        if self.isRunning == false {
            self.portUDP = UInt16(Int(number)!)
            print(self.portUDP)
        }
    }
    
    func updSocket(_ socket: SwiftAsyncUDPSocket, didReceive data: Data, from address: SwiftAsyncUDPSocketAddress, withFilterContext filterContext: Any?) {
        if !data.isEmpty, data.count >= 20 {
            let data = [UInt8](data)
            let type = [UInt8](data[16...19])
            
            switch type {
            case DSUMessage.TYPE_PORTS:
                print("Received: Message Type: PORTS")
                self.handleIncomingPortsRequest(socket: socket, fromAddress: address, data: data)
                break
            case DSUMessage.TYPE_DATA:
                print("Received: Message Type: DATA")
                self.handleIncomingDataRequest(socket: socket, fromAddress: address, data: data)
                break
            case DSUMessage.TYPE_VERSION:
                print("Message Type: VERSION")
                break
            default:
                print("Uknown message type")
            }
        }
    }
    
    func updSocket(_ socket: SwiftAsyncUDPSocket, didNotSendDataWith tag: Int, dueTo error: SwiftAsyncSocketError) {
        print("did not send data error: \(error)")
    }
    
    func handleIncomingPortsRequest(socket: SwiftAsyncUDPSocket, fromAddress: SwiftAsyncUDPSocketAddress, data: [UInt8]) {
        let requestsCount = data[20] // aka, the number of slots the client asked for
        
        for i in 0..<requestsCount {
            let dataMessage = self.getPortsPacket(index: i)
            do {
                try socket.send(data: Data(dataMessage), address: fromAddress.address, tag: 23)
            } catch {
                print("could not send ports data")
            }
        }
    }
    
    func handleIncomingDataRequest(socket: SwiftAsyncUDPSocket, fromAddress: SwiftAsyncUDPSocketAddress, data: [UInt8]) {
        let slotBased = data[20]
        let reqSlot = Int(data[21])
        let flags = data[24]
        let regId = data[25]
        
        if flags == 0 && regId == 0 {
            let clientAddress = fromAddress.host
            if self.clients[clientAddress] == nil {
                print("New client connection: \(fromAddress.host) \(fromAddress.port)")
                self.clients[clientAddress] = Client(server: self, socket: socket, address: fromAddress, port: fromAddress.port)
                self.clients[clientAddress]!.setSlot(slot: reqSlot)
                self.updateClientsViewModel()
            } else {
                if self.clients[clientAddress]!.port != fromAddress.port {
                    print("Refresh existing connection: \(clientAddress) \(fromAddress.port) (prevPort: \(self.clients[clientAddress]!.port))")
                    self.clients[clientAddress]?.close()
                    self.clients[clientAddress] = Client(server: self, socket: socket, address: fromAddress, port: fromAddress.port)
                }
                self.clients[clientAddress]!.setSlot(slot: reqSlot)
                self.clients[clientAddress]!.setTimeStampOnDataRequest()
            }
        
            if self.controllerService != nil {
                if slotBased == 0x01 {
                    if self.controllerService!.connectedControllers[reqSlot] != nil {
                        report(controller: self.controllerService!.connectedControllers[reqSlot]!)
                    }
                } else {
                    for dsuController in self.controllerService!.connectedControllers {
                        report(controller: dsuController.value)
                    }
                }
            }
        } else {
            print("flags: \(flags), regId: \(regId)")
        }
    }
    
    func getPortsPacket(index: UInt8) -> [UInt8] {
        if self.controllerService != nil && index <= self.controllerService!.numberOfControllersConnected && self.controllerService!.connectedControllers[Int(index)] != nil {
            return DSUMessage.make(type: DSUMessage.TYPE_PORTS, data: self.controllerService!.connectedControllers[Int(index)]!.getInfoPacket())
        }
        return DSUMessage.make(type: DSUMessage.TYPE_PORTS, data: DSUController.defaultInfoPacket(index: index))
    }
    
    func report(controller: DSUController) {
        for (_, client) in self.clients {
            if client.slots[Int(controller.slot)] {
//                print("\(Date.init().timeIntervalSince1970.description) sending controller data to client \(client.address.host):\(client.port), slot: \(controller.slot)")
                self.backgroundQueueUdpConnection.sync {
                    client.send(dataMessage: Data(controller.getDataPacket(counter: self.counter)))
                }
            }
        }
        self.counter += 1
    }
    
    func updateClientsViewModel() {
        DispatchQueue.main.async {
            self.clientsViewModel.clients = self.clients
        }
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
