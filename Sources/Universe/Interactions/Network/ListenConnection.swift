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
        logAThing(logger: self.universe.logger, logMessage: "🔌 ListenConnection readWithLengthPrefix")
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
        logAThing(logger: self.universe.logger, logMessage: "🔌 ListenConnection writeWithLengthPrefix")
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

    func read(_ style: NetworkListenReadStyle) -> Data
    {
        let result = self.universe.processEffect(NetworkListenReadRequest(self.uuid, style))
        switch result
        {
            case let response as NetworkListenReadResponse:
                return response.data
            default:
                logAThing(logger: self.universe.logger, logMessage: "\n🪐 ~* Received an unexpectec NetworkListenReadResponse: \(result)\n")
                return Data()
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
