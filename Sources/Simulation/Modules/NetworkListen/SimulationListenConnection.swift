//
//  SimulationConnection.swift
//  
//
//  Created by Dr. Brandon Wiley on 3/1/22.
//

import Chord
import Foundation
import Spacetime
import TransmissionTypes

public class SimulationListenConnection
{
    let networkConnection: TransmissionTypes.Connection
    fileprivate var reads: [UUID: Read] = [:]
    fileprivate var writes: [UUID: Write] = [:]
    fileprivate var closes: [UUID: Close] = [:]

    public init(_ networkConnection: TransmissionTypes.Connection)
    {
        self.networkConnection = networkConnection
    }

    public func read(request: NetworkListenReadRequest, channel: BlockingQueue<Event>)
    {
        let read = Read(simulationConnection: self, networkConnection: self.networkConnection, request: request, events: channel)
        self.reads[read.uuid] = read
    }

    public func write(request: NetworkListenWriteRequest, channel: BlockingQueue<Event>)
    {
        let write = Write(simulationConnection: self, networkConnection: self.networkConnection, request: request, events: channel)
        self.writes[write.uuid] = write
    }

    public func close(request: NetworkListenCloseRequest, state: NetworkListenModule, channel: BlockingQueue<Event>)
    {
        let close = Close(simulationConnection: self, networkConnection: self.networkConnection, state: state, request: request, events: channel)
        self.closes[close.uuid] = close
    }
}

fileprivate struct Read
{
    let simulationConnection: SimulationListenConnection
    let networkConnection: TransmissionTypes.Connection
    let request: NetworkListenReadRequest
    let events: BlockingQueue<Event>
    let queue = DispatchQueue(label: "SimulationListenConnection.Read")
    let response: NetworkListenReadResponse? = nil
    let uuid = UUID()

    public init(simulationConnection: SimulationListenConnection, networkConnection: TransmissionTypes.Connection, request: NetworkListenReadRequest, events: BlockingQueue<Event>)
    {
        self.simulationConnection = simulationConnection
        self.networkConnection = networkConnection
        self.request = request
        self.events = events

        let uuid = self.uuid

        self.queue.async
        {
            switch request.style
            {
                case .exactSize(let size):
                    guard let result = networkConnection.read(size: size) else
                    {
                        let failure = Failure(request.id)
                        events.enqueue(element: failure)
                        return
                    }

                    let response = NetworkListenReadResponse(request.id, request.socketId, result)
                    print(response.description)
                    events.enqueue(element: response)

                case .maxSize(let size):
                    guard let result = networkConnection.read(maxSize: size) else
                    {
                        let failure = Failure(request.id)
                        events.enqueue(element: failure)
                        return
                    }

                    let response = NetworkListenReadResponse(request.id, request.socketId, result)
                    print(response.description)
                    events.enqueue(element: response)

                case .lengthPrefixSizeInBits(let prefixSize):
                    guard let result = networkConnection.readWithLengthPrefix(prefixSizeInBits: prefixSize) else
                    {
                        let failure = Failure(request.id)
                        print(failure.description)
                        events.enqueue(element: failure)
                        return
                    }

                    let response = NetworkListenReadResponse(request.id, request.socketId, result)
                    print(response.description)
                    events.enqueue(element: response)
            }

            simulationConnection.reads.removeValue(forKey: uuid)
        }
    }
}

fileprivate struct Write
{
    let simulationConnection: SimulationListenConnection
    let networkConnection: TransmissionTypes.Connection
    let request: NetworkListenWriteRequest
    let events: BlockingQueue<Event>
    let queue = DispatchQueue(label: "SimulationConnection.Write")
    let uuid = UUID()

    public init(simulationConnection: SimulationListenConnection, networkConnection: TransmissionTypes.Connection, request: NetworkListenWriteRequest, events: BlockingQueue<Event>)
    {
        self.simulationConnection = simulationConnection
        self.networkConnection = networkConnection
        self.request = request
        self.events = events

        let uuid = self.uuid

        queue.async
        {
            if let prefixSize = request.lengthPrefixSizeInBits
            {
                guard networkConnection.writeWithLengthPrefix(data: request.data, prefixSizeInBits: prefixSize) else
                {
                    let failure = Failure(request.id)
                    events.enqueue(element: failure)
                    return
                }

                let response = NetworkListenWriteResponse(request.id)
                print(response.description)
                events.enqueue(element: response)
            }
            else
            {
                guard networkConnection.write(data: request.data) else
                {
                    let failure = Failure(request.id)
                    events.enqueue(element: failure)
                    return
                }

                let response = NetworkListenWriteResponse(request.id)
                print(response.description)
                events.enqueue(element: response)
            }

            simulationConnection.writes.removeValue(forKey: uuid)
        }
    }
}

fileprivate struct Close
{
    let simulationConnection: SimulationListenConnection
    let networkConnection: TransmissionTypes.Connection
    let request: NetworkListenCloseRequest
    let state: NetworkListenModule
    let events: BlockingQueue<Event>
    let queue = DispatchQueue(label: "SimulationConnection.Close")
    let uuid = UUID()

    public init(simulationConnection: SimulationListenConnection, networkConnection: TransmissionTypes.Connection, state: NetworkListenModule, request: NetworkListenCloseRequest, events: BlockingQueue<Event>)
    {
        self.simulationConnection = simulationConnection
        self.networkConnection = networkConnection
        self.state = state
        self.request = request
        self.events = events

        let uuid = self.uuid

        queue.async
        {
            networkConnection.close()

            let response = Affected(request.id)
            print(response.description)
            events.enqueue(element: response)

            state.connections.removeValue(forKey: uuid)
            simulationConnection.closes.removeValue(forKey: uuid)
        }
    }
}
