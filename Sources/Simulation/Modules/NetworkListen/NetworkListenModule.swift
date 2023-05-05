//
//  NetworkListenModule.swift
//
//
//  Created by Dr. Brandon Wiley on 3/23/22.
//

import Chord
import Foundation

#if os(macOS) || os(iOS)
import os.log
#else
import Logging
#endif

import Spacetime
import Transmission

public class NetworkListenModule: Module
{
    static public let name = "networkListen"

    public var logger: Logger?
    public var connections: [UUID: SimulationListenConnection] = [:]

    let lock = DispatchSemaphore(value: 1)

    var listeners: [UUID: SimulationListener] = [:]

    public func name() -> String
    {
        return NetworkListenModule.name
    }
    
    public func setLogger(logger: Logger?)
    {
        self.logger = logger
    }

    public func handleEffect(_ effect: Effect, _ channel: BlockingQueue<Event>) -> Event?
    {
        switch effect
        {
            case let request as AcceptRequest:
                let listenUuid = request.socketId

                self.lock.wait()
                guard let listener = self.listeners[listenUuid] else
                {
                    self.lock.signal()
                    return Failure(request.id)
                }
                self.lock.signal()

                listener.accept(request: request, state: self, channel: channel)
                return nil

            case let request as ListenRequest:
                guard let uuid = listen(port: request.port, type: request.type) else
                {
                    return Failure(effect.id)
                }

                return ListenResponse(effect.id, uuid)

            case let request as NetworkListenReadRequest:
                let uuid = request.socketId

                self.lock.wait()
                guard let connection = self.connections[uuid] else
                {
                    self.lock.signal()
                    return Failure(request.id)
                }
                self.lock.signal()

                connection.read(request: request, channel: channel)
                return nil

            case let request as NetworkListenWriteRequest:
                let uuid = request.socketId

                self.lock.wait()
                guard let connection = self.connections[uuid] else
                {
                    self.lock.signal()
                    return Failure(request.id)
                }
                self.lock.signal()

                connection.write(request: request, channel: channel)
                return nil

            case let request as NetworkListenCloseRequest:
                let uuid = request.socketId

                self.lock.wait()
                if let connection = self.connections[uuid]
                {
                    self.lock.signal()
                    connection.close(request: request, state: self, channel: channel)
                    return nil
                }
                else
                {
                    self.lock.signal()

                    self.lock.wait()
                    if let listener = self.listeners[uuid]
                    {
                        self.lock.signal()
                        listener.close(request: request, state: self, channel: channel)
                        return nil
                    }
                    else
                    {
                        self.lock.signal()
                        return Failure(request.id)
                    }
                }

            default:
                return Failure(effect.id)
        }
    }

    public func handleExternalEvent(_ event: Event)
    {
        return
    }

    func listen(port: Int, type: ConnectionType) -> UUID?
    {
        let uuid = UUID()
        guard let networkListener = TransmissionListener(port: port, type: type, logger: nil) else
        {
            return nil
        }

        let listener = SimulationListener(networkListener, logger: self.logger)

        defer
        {
            self.lock.signal()
        }
        self.lock.wait()

        self.listeners[uuid] = listener

        return uuid
    }
}
