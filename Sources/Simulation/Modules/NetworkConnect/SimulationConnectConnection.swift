//
//  SimulationConnection.swift
//  
//
//  Created by Dr. Brandon Wiley on 3/1/22.
//

import Chord
import Foundation

#if os(macOS) || os(iOS)
import os.log
#else
import Logging
#endif

import Spacetime
import TransmissionTypes

public class SimulationConnectConnection
{
    let logger: Logger?
    let networkConnection: TransmissionTypes.Connection
    fileprivate var reads: [UUID: Read] = [:]
    fileprivate var writes: [UUID: Write] = [:]
    fileprivate var closes: [UUID: Close] = [:]

    public init(_ networkConnection: TransmissionTypes.Connection, logger: Logger? = nil)
    {
        self.logger = logger
        self.networkConnection = networkConnection
    }

    public func read(request: NetworkConnectReadRequest, channel: BlockingQueue<Event>)
    {
        let read = Read(simulationConnection: self, networkConnection: self.networkConnection, request: request, events: channel, logger: logger)
        self.reads[read.uuid] = read
    }

    public func write(request: NetworkConnectWriteRequest, channel: BlockingQueue<Event>)
    {
        let write = Write(simulationConnection: self, networkConnection: self.networkConnection, request: request, events: channel, logger: logger)
        self.writes[write.uuid] = write
    }

    public func close(request: NetworkConnectCloseRequest, state: NetworkConnectModule, channel: BlockingQueue<Event>)
    {
        let close = Close(simulationConnection: self, networkConnection: self.networkConnection, state: state, request: request, events: channel)
        self.closes[close.uuid] = close
    }
}

fileprivate struct Read
{
    let logger: Logger?
    let simulationConnection: SimulationConnectConnection
    let networkConnection: TransmissionTypes.Connection
    let request: NetworkConnectReadRequest
    let events: BlockingQueue<Event>
    let queue = DispatchQueue(label: "SimulationConnection.Read")
    let response: NetworkConnectReadResponse? = nil
    let uuid = UUID()

    public init(simulationConnection: SimulationConnectConnection, networkConnection: TransmissionTypes.Connection, request: NetworkConnectReadRequest, events: BlockingQueue<Event>, logger: Logger? = nil)
    {
        self.simulationConnection = simulationConnection
        self.networkConnection = networkConnection
        self.request = request
        self.events = events
        self.logger = logger

        let uuid = self.uuid

        self.queue.async
        {
            switch request.style
            {
                case .exactSize(let size):
                    logAThing(logger: logger, logMessage: "📖 SimulationConnectConnection.Read: case .exactSize(\(size))")
                    guard let result = networkConnection.read(size: size) else
                    {
                        let failure = Failure(request.id)
                        print(failure.description)
                        events.enqueue(element: failure)
                        return
                    }

                    let response = NetworkConnectReadResponse(request.id, request.socketId, result)
                    logAThing(logger: logger, logMessage: "SimulationConnectConnection: \(response.description)")
                    events.enqueue(element: response)
                    
                case .unsafeExactSize(let size):
                    logAThing(logger: logger, logMessage: "📖 SimulationConnectConnection.Read: case .unsafeExactSize(\(size)")
                    guard let result = networkConnection.unsafeRead(size: size) else
                    {
                        let failure = Failure(request.id)
                        print(failure.description)
                        events.enqueue(element: failure)
                        return
                    }

                    let response = NetworkConnectReadResponse(request.id, request.socketId, result)
                    logAThing(logger: logger!, logMessage: "SimulationConnectConnection: \(response.description)")
                    events.enqueue(element: response)
                    
                case .maxSize(let size):
                    logAThing(logger: logger, logMessage: "📖 SimulationConnectConnection.Read: case .maxSize(\(size))")
                    guard let result = networkConnection.read(maxSize: size) else
                    {
                        let failure = Failure(request.id)
                        print(failure.description)
                        events.enqueue(element: failure)
                        return
                    }

                    let response = NetworkConnectReadResponse(request.id, request.socketId, result)
                    print(response.description)
                    events.enqueue(element: response)
                    
                case .lengthPrefixSizeInBits(let prefixSize):
                    logAThing(logger: logger, logMessage: "📖 SimulationConnectConnection.Read: case .lengthPrefixSizeInBits(\(prefixSize))")
                    guard let result = networkConnection.readWithLengthPrefix(prefixSizeInBits: prefixSize) else
                    {
                        let failure = Failure(request.id)
                        logAThing(logger: logger, logMessage: "🛑 SimulationConnectConnection.Read: case .lengthPrefixSizeInBits failed: \(failure.description)")
                        events.enqueue(element: failure)
                        return
                    }
                    
                    if result.isEmpty
                    {
                        logAThing(logger: logger, logMessage: "🛑 SimulationConnectConnection.Read: case .lengthPrefixSizeInBits returned an empty data.")
                    }
                    
                    let response = NetworkConnectReadResponse(request.id, request.socketId, result)
                    print(response.description)
                    events.enqueue(element: response)
            }

            simulationConnection.reads.removeValue(forKey: uuid)
        }
    }
}

fileprivate struct Write
{
    let logger: Logger?
    let simulationConnection: SimulationConnectConnection
    let networkConnection: TransmissionTypes.Connection
    let request: NetworkConnectWriteRequest
    let events: BlockingQueue<Event>
    let queue = DispatchQueue(label: "SimulationConnection.Write")
    let uuid = UUID()

    public init(simulationConnection: SimulationConnectConnection, networkConnection: TransmissionTypes.Connection, request: NetworkConnectWriteRequest, events: BlockingQueue<Event>, logger: Logger? = nil)
    {
        self.simulationConnection = simulationConnection
        self.networkConnection = networkConnection
        self.request = request
        self.events = events
        self.logger = logger

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

                let response = Affected(request.id)
                
                if logger != nil
                {
                    logAThing(logger: logger!, logMessage: "SimulationConnectConnection: \(response.description)")
                }
                
                print(response.description)
                events.enqueue(element: response)
            }
            else
            {
                guard networkConnection.write(data: request.data) else
                {
                    let failure = Failure(request.id)
                    print(failure.description)
                    events.enqueue(element: failure)
                    return
                }

                let response = Affected(request.id)
                print(response.description)
                events.enqueue(element: response)
            }

            simulationConnection.writes.removeValue(forKey: uuid)
        }
    }
}

fileprivate struct Close
{
    let simulationConnection: SimulationConnectConnection
    let networkConnection: TransmissionTypes.Connection
    let request: NetworkConnectCloseRequest
    let state: NetworkConnectModule
    let events: BlockingQueue<Event>
    let queue = DispatchQueue(label: "SimulationConnection.Close")
    let uuid = UUID()

    public init(simulationConnection: SimulationConnectConnection, networkConnection: TransmissionTypes.Connection, state: NetworkConnectModule, request: NetworkConnectCloseRequest, events: BlockingQueue<Event>)
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
