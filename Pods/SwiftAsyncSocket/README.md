# SwiftAsyncSocket
 [![Version Status](https://img.shields.io/cocoapods/v/SwiftAsyncSocket.svg?style=flat)](http://cocoadocs.org/docsets/SwiftAsyncSocket) [![Platform](http://img.shields.io/cocoapods/p/SwiftAsyncSocket.svg?style=flat)](http://cocoapods.org/?q=SwiftAsyncSocket) [![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage) ![GitHub license](https://img.shields.io/badge/license-MIT-lightgrey.svg)

SwiftAsyncSocket is a socket connnection tool based on GCD with full implement by **Swift**. 

I translated it from [CocoaAsyncSocket](https://github.com/robbiehanson/CocoaAsyncSocket).

In other words, if you have experience to use **CocoaAsyncSocket**, you will feel familar to this.

**SwiftAsyncSocket** can support both TCP/IP and UDP/IP socket.

**SwiftAsyncSocket** is heavier then **CocoaAsyncSocket**. Because there is more then 8,000 line in one file of **CocoaAsyncSocket**. I scattered these logic across multiple files.

**SwiftAsyncSocket** has already passed **SwiftLint** check.

## Installation
### 1. Mannual install
**SwiftAsyncSocket** now support **Cocoapods**

So now you can only use this by those steps.

```
# Download the source of the code 
git clone https://github.com/chouheiwa/SwiftAsnycSocket.git

cd SwiftAsnycSocket

open ./SwiftAsyncSocket.xcodeproj
```

Then open xcodeproj file. And use `cmd + b` to build a framework. Finally copy it to your work.
### 2. CocoaPods
Install using [CocoaPods](http://cocoapods.org) by adding this line to your Podfile:

````ruby
use_frameworks! # Add this if you are targeting iOS 8+ or using Swift
pod 'SwiftAsyncSocket'  
````
### 3.Carthage
SwiftAsyncSocket is [Carthage](https://github.com/Carthage/Carthage) compatible. To include it add the following line to your `Cartfile`

```bash
github "chouheiwa/SwiftAsyncSocket"
```


## Usage
#### TCP/IP
##### 1. Use as client. 

If there has a socket server start at localhost:8080
```Swift
import SwiftAsyncSocket

class Client {
    var socket: SwiftAsyncSocket
    
    init() {
        // you can not set delegate here because in this line that init function has not complete.So set delegate next line
        socket = SwiftAsyncSocket(delegate: nil, delegateQueue: DispatchQueue.global(), socketQueue: nil)
        // All the delagate function is optional. If you want to use. You can implement it.
        socket.delgate = self
        
        do {
            // Connected 
            try socket.connect(toHost: "localhost", onPort: 8080)
        } catch {
            // Here to print error
            print("\(error)")
        }
    }
}
/// If you want to use as client, 
/// at least you need to implement these three method
extension Client: SwiftAsyncSocketDelgate {
    func socket(_ socket: SwiftAsyncSocket, didConnect toHost: String, port: UInt16) {
        // If you use socket.connect(toHost: , onPort: )
        // When the socket connected, this method will be called
        // Then you can call 
        // socket.write(data:, timeOut:, tag:) 
        // to send the data to server or 
        // socket.readData(timeOut:, tag:)
        // to read data from server
        
    }
    
    func socket(_ socket: SwiftAsyncSocket, didWriteDataWith tag: Int) {
        // When send data complete, this method will be called
    }

    func socket(_ socket: SwiftAsyncSocket, didRead data: Data, with tag: Int) {
        // When read data complete, this method will return the data from server
    }
}

```
##### 2. Use as server.
```Swift
import Foundation
import SwiftAsyncSocket
class Server: SwiftAsyncSocketDelegate {
    var baseSocket: SwiftAsyncSocket
    /// Here we use map to help we locate which socket has already been disconnected
    var acceptSockets: [String:SwiftAsyncSocket] = [:]

    var port: UInt16

    var canAccept: Bool = false

    var canSendData: ((SwiftAsyncSocket) -> Void)?

    var didReadData: ((Data) -> Void)?

    init() {
        baseSocket = SwiftAsyncSocket(delegate: nil, delegateQueue: DispatchQueue.global(), socketQueue: nil)

        port = UInt16.random(in: 1024..<50000)

        baseSocket.delegate = self

        do {
            canAccept = try baseSocket.accept(port: port)

            canAccept = true
        } catch let error as SwiftAsyncSocketError {
            print("\(error)")
        } catch {
            fatalError("\(error)")
        }
    }

    func socket(_ socket: SwiftAsyncSocket, didAccept newSocket: SwiftAsyncSocket) {
        /// We use a time and a random number to make key unique
        let random = Int.random(in: 0..<99999)

        let date = Date()
        let key = "\(date)\(random)"
        acceptSockets[key] = newSocket
        newSocket.userData = key
        newSocket.delegate = self
        newSocket.delegateQueue = DispatchQueue.global()
        canSendData?(newSocket)
    }

    func socket(_ socket: SwiftAsyncSocket, didWriteDataWith tag: Int) {

    }

    func socket(_ socket: SwiftAsyncSocket, didRead data: Data, with tag: Int) {
        didReadData?(data)
    }

    func socket(_ socket: SwiftAsyncSocket?, didDisconnectWith error: SwiftAsyncSocketError?) {
        guard let key = socket?.userData as? String else { return }

        acceptSockets.removeValue(forKey: key)
    }
}
```

#### UDP
##### 1. Use as client. 
```Swift
import Foundation
import SwiftAsyncSocket

class UdpClient {
    var socket: SwiftAsyncUDPSocket
    
    init() {
        // you can not set delegate here because in this line that init function has not complete.So set delegate next line
        serverSocket = SwiftAsyncUDPSocket(delegate: nil, delegateQueue: DispatchQueue.main)
        // All the delagate function is optional. If you want to use. You can implement it.
        socket.delgate = self
        
        do {
            // Connected 
            try socket.connect(toHost: "localhost", onPort: 8090)
        } catch {
            // Here to print error
            print("\(error)")
        }
    }
    
    func sendData() {
        let data = "data".data(using: .utf8) ?? Data()
        
        do {
            socket.send(data: data, timeout: -1, tag: 10)
            // Use next line if you want to receive data
            try socket.receiveAlways()
        } catch {
            print("\(error)")
        }
    }
}
/// You don't need implement any method to send data
extension Client: SwiftAsyncUDPSocketDelgate {
    func updSocket(_ socket: SwiftAsyncUDPSocket,
                   didReceive data: Data,
                   from address: SwiftAsyncUDPSocketAddress,
                   withFilterContext filterContext: Any?) {
                   
    }
}
```

##### 2. Use as server.

```Swift
import Foundation
import SwiftAsyncSocket

class UdpServer {
    let port: UInt16
    let serverSocket: SwiftAsyncUDPSocket

    var didReceiveData: ((Data) -> Void)?

    init(port: UInt16) throws {
        self.port = port
        serverSocket = SwiftAsyncUDPSocket(delegate: nil, delegateQueue: DispatchQueue.main)

        serverSocket.delegate = self

        try serverSocket.bind(port: port)

        try serverSocket.receiveAlways()
    }
}
extension UdpServer: SwiftAsyncUDPSocketDelegate {
    func updSocket(_ socket: SwiftAsyncUDPSocket,
                   didReceive data: Data,
                   from address: SwiftAsyncUDPSocketAddress,
                   withFilterContext filterContext: Any?) {
                   
        let string = String(data: data, encoding: .utf8) ?? ""
        print("Receive Data: \(string)")
    }
}
```
