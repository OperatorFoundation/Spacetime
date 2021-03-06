//
//  ConnectRequest.swift
//  
//
//  Created by Dr. Brandon Wiley on 2/4/22.
//

import Foundation
import TransmissionTypes

public class ConnectRequest: Effect
{
    public let address: String
    public let port: Int
    public let type: ConnectionType

    public override var description: String
    {
        return "\(self.module).ConnectRequest[id: \(self.id), port: \(self.port), type: \(self.type)]"
    }

    public init(_ address: String, _ port: Int, _ type: ConnectionType)
    {
        self.address = address
        self.port = port
        self.type = type

        super.init(module: BuiltinModuleNames.networkConnect.rawValue)
    }
}
