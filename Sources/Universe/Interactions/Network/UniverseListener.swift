//
//  Listener.swift
//  
//
//  Created by Dr. Brandon Wiley on 2/4/22.
//

import Chord
import Foundation
import Spacetime
import TransmissionTypes

open class UniverseListener: TransmissionTypes.Listener
{
    public let universe: Universe
    public let uuid: UUID

    public init(universe: Universe, address: String, port: Int, type: ConnectionType = .tcp) throws
    {
        let result = universe.processEffect(ListenRequest(address, port, type))
        switch result
        {
            case let response as ListenResponse:
                self.universe = universe
                self.uuid = response.socketId
                return
            case is Failure:
                throw ListenerError.badResponse(result)
            default:
                throw ListenerError.badResponse(result)
        }
    }

    public init(universe: Universe, uuid: UUID)
    {
        self.universe = universe
        self.uuid = uuid
    }

    open func accept() throws -> TransmissionTypes.Connection
    {
        let result = self.universe.processEffect(AcceptRequest(self.uuid))
        switch result
        {
            case let response as AcceptResponse:
                return ListenConnection(universe: self.universe, response.socketId)
            default:
                throw ListenerError.acceptFailed
        }
    }

    open func close()
    {
        let result = self.universe.processEffect(NetworkListenCloseRequest(self.uuid))
        switch result
        {
            case is NetworkListenCloseResponse:
                return
            default:
                return
        }
    }
}

extension Universe
{
    public func listen(_ address: String, _ port: Int, type: ConnectionType = .tcp) throws -> UniverseListener
    {
        return try UniverseListener(universe: self, address: address, port: port, type: type)
    }
}

public enum ListenerError: Error
{
    case portInUse(Int) // port
    case badResponse(Event)
    case acceptFailed
}
