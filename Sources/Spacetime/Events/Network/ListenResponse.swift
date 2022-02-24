//
//  ListenResponse.swift
//  
//
//  Created by Dr. Brandon Wiley on 2/4/22.
//

import Foundation

public class ListenResponse: Event
{
    public let socketId: UUID

    public init(_ socketId: UUID)
    {
        self.socketId = socketId
    }
}
