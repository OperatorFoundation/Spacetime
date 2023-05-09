//
//  Connection.swift
//  
//
//  Created by Dr. Brandon Wiley on 2/4/22.
//

#if os(macOS) || os(iOS)
import os.log
#else
import Logging
#endif

import Chord
import Datable
import Foundation
import Spacetime
import TransmissionTypes

public class ConnectConnection: TransmissionTypes.Connection
{
    public let universe: Universe
    public let uuid: UUID

    public init?(universe: Universe, address: String, port: Int, type: ConnectionType = .tcp)
    {
        let result = universe.processEffect(ConnectRequest(address, port, type))
        switch result
        {
            case let response as ConnectResponse:
                self.universe = universe
                self.uuid = response.socketId
                return
            case is Failure:
                return nil
            default:
                return nil
        }
    }

    public init(universe: Universe, _ uuid: UUID)
    {
        self.universe = universe
        self.uuid = uuid
    }

    public func read(size: Int) -> Data?
    {
        return self.read(.exactSize(size))
    }

    public func unsafeRead(size: Int) -> Data?
    {
        return self.read(.exactSize(size))
    }

    public func read(maxSize: Int) -> Data?
    {
        return self.read(.maxSize(maxSize))
    }

    public func readWithLengthPrefix(prefixSizeInBits: Int) -> Data?
    {
        return self.read(.lengthPrefixSizeInBits(prefixSizeInBits))
    }

    public func write(string: String) -> Bool
    {
        return self.write(data: string.data)
    }

    public func write(data: Data) -> Bool
    {
        return self.spacetimeWrite(data: data)
    }

    public func writeWithLengthPrefix(data: Data, prefixSizeInBits: Int) -> Bool
    {
        logAThing(logger: self.universe.logger, logMessage: "🔌 ConnectConnection readWithLengthPrefix")
        return self.spacetimeWrite(data: data, prefixSizeInBits: prefixSizeInBits)
    }

    public func close()
    {
        let result = self.universe.processEffect(NetworkConnectCloseRequest(self.uuid))
        switch result
        {
            case is Affected:
                return
            default:
                return
        }
    }

    func read(_ style: NetworkConnectReadStyle) -> Data
    {
        let result = self.universe.processEffect(NetworkConnectReadRequest(self.uuid, style))
        switch result
        {
            case let response as NetworkConnectReadResponse:
                return response.data
            default:
                return Data()
        }
    }

    public func spacetimeWrite(data: Data, prefixSizeInBits: Int? = nil) -> Bool
    {
        let result = self.universe.processEffect(NetworkConnectWriteRequest(self.uuid, data, prefixSizeInBits))
        switch result
        {
            case is Affected:
                return true
            default:
                return false
        }
    }
}

// add destinationHost() function that gets the host name

extension Universe
{
    public func connect(_ address: String, _ port: Int, _ type: ConnectionType = .tcp) throws -> Connection
    {
        guard let connection = ConnectConnection(universe: self, address: address, port: port, type: type) else
        {
            throw ConnectConnectionError.connectionRefused
        }

        return connection
    }
}

public enum ConnectConnectionError: Error
{
    case connectionRefused
}
