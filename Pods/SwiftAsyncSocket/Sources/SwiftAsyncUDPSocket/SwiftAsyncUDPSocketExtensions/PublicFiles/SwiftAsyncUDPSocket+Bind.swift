//
//  SwiftAsyncUDPSocket+Bind.swift
//  SwiftAsyncSocket
//
//  Created by chouheiwa on 2019/1/18.
//  Copyright © 2019 chouheiwa. All rights reserved.
//

import Foundation
// MARK: - Bind
extension SwiftAsyncUDPSocket {
    /// Binds the UDP socket to the given port and optional interface.
    /// Binding should be done for server sockets that receive data prior to sending it.
    /// Client sockets can skip binding,
    /// as the OS will automatically assign the socket an available port when it starts sending data.
    ///
    /// You cannot bind a socket after its been connected.
    /// You can only bind a socket once.
    /// You can still connect a socket (if desired) after binding.
    ///
    /// - Parameters:
    ///   - interface:
    ///         - The interface may be a name (e.g. "en1" or "lo0")
    ///           or the corresponding IP address (e.g. "192.168.1.105").
    ///         - You may also use the special strings "localhost" or "loopback" to
    ///           specify that the socket only accept packets from the local machine.
    ///   - port:
    ///         - You may optionally pass a port number of zero to immediately bind the
    ///           socket, yet still allow the OS to automatically assign an available
    ///            port.
    /// - Throws: Bind error
    public func bind(to interface: String? = nil,
                     port: UInt16) throws {
        var errors: SwiftAsyncSocketError?

        socketQueueDo {
            do {
                try self.preBind()

                guard let dataType = SocketDataType.getInterfaceAddress(interface: interface ?? "",
                                                                        port: port) else {
                    throw SwiftAsyncSocketError.badParamError("Unknown interface. "
                        + "Specify valid interface by name (e.g. \"en1\") or IP address.")
                }
                try self.bind(toData: dataType)

                self.flags.insert(.didBind)
            } catch let error as SwiftAsyncSocketError {
                errors = error
            } catch {
                fatalError("\(error)")
            }
        }

        if let error = errors {
            throw error
        }
    }

    /// Bind to a given socket data
    ///
    /// - Parameter address: given socket data
    /// - Throws: Bind error
    public func bind(to address: Data) throws {
        var errors: SwiftAsyncSocketError?

        socketQueueDo {
            do {
                try self.preBind()

                try self.bind(toData: try SocketDataType(data: address))

                self.flags.insert(.didBind)
            } catch let error as SwiftAsyncSocketError {
                errors = error
            } catch {
                fatalError("\(error)")
            }
        }

        if let error = errors {
            throw error
        }
    }
}
