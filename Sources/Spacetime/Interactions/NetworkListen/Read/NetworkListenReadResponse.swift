//
//  NetworkReadResponse.swift
//  
//
//  Created by Dr. Brandon Wiley on 2/4/22.
//

import Foundation

public class NetworkListenReadResponse: Event
{
    public let socketId: UUID
    public let data: Data

    public override var description: String
    {
        return "\(self.module).NetworkListenReadResponse[effectID: \(String(describing: self.effectId)), socketId: \(self.socketId), data: \(self.data)]"
    }

    public init(_ effectId: UUID, _ socketId: UUID, _ data: Data)
    {
        self.socketId = socketId
        self.data = data

        super.init(effectId, module: BuiltinModuleNames.networkListen.rawValue)
    }

    enum CodingKeys: String, CodingKey
    {
        case effectId
        case socketId
        case data
    }

    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let effectId = try container.decode(UUID.self, forKey: .effectId)
        let socketId = try container.decode(UUID.self, forKey: .socketId)
        let data = try container.decode(Data.self, forKey: .data)

        self.socketId = socketId
        self.data = data
        super.init(effectId, module: BuiltinModuleNames.networkListen.rawValue)
    }
}
