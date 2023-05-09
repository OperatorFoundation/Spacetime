//
//  Connection.swift
//  
//
//  Created by Dr. Brandon Wiley on 2/4/22.
//

import Chord
import Datable
import Foundation
import Spacetime
import TransmissionTypes

public class ListenConnection: TransmissionTypes.Connection
{
    public let universe: Universe
    public let uuid: UUID

    public init(universe: Universe, _ uuid: UUID)
    {
        self.universe = universe
        self.uuid = uuid
    }

    public func read(size: Int) -> Data?
    {
        do
        {
            return try self.read(.exactSize(size))
        }
        catch
        {
            logAThing(logger: nil, logMessage: "ListenConnection: read(size:) received an error: \(error)")
            return nil
        }
    }

    public func unsafeRead(size: Int) -> Data?
    {
        do
        {
            return try self.read(.exactSize(size))
        }
        catch
        {
            logAThing(logger: nil, logMessage: "ListenConnection: unsafeRead(size:) received an error: \(error)")
            return nil
        }
    }

    public func read(maxSize: Int) -> Data?
    {
        do
        {
            return try self.read(.maxSize(maxSize))
        }
        catch
        {
            logAThing(logger: nil, logMessage: "ListenConnection: read(maxSize:) received an error: \(error)")
            return nil
        }
    }

    public func readWithLengthPrefix(prefixSizeInBits: Int) -> Data?
    {
        do
        {
            return try self.read(.lengthPrefixSizeInBits(prefixSizeInBits))
        }
        catch
        {
            logAThing(logger: nil, logMessage: "ListenConnection: readWithLengthPrefix(prefixSizeInBits:) received an error: \(error)")
            return nil
        }
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
        return self.spacetimeWrite(data: data, prefixSizeInBits: prefixSizeInBits)
    }

    public func close()
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

    func read(_ style: NetworkListenReadStyle) throws -> Data
    {
        let result = self.universe.processEffect(NetworkListenReadRequest(self.uuid, style))
        switch result
        {
            case let response as NetworkListenReadResponse:
                return response.data
            default:
                logAThing(logger: self.universe.logger, logMessage: "\n🪐 Received an unexpected NetworkListenReadResponse: \(result)\n")
                throw ListenerError.badResponse(result)
        }
    }

    public func spacetimeWrite(data: Data, prefixSizeInBits: Int? = nil) -> Bool
    {
        let result = self.universe.processEffect(NetworkListenWriteRequest(self.uuid, data, prefixSizeInBits))
        switch result
        {
            case is NetworkListenWriteResponse:
                return true
            case is Affected:
                return true
            default:
                print("bad write \(result)")
                print("bad write type \(type(of: result))")
                return false
        }
    }
}
