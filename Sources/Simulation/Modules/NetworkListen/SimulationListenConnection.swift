//
//  SimulationConnection.swift
//  
//
//  Created by Dr. Brandon Wiley on 3/1/22.
//

import Foundation
#if os(macOS) || os(iOS)
import os.log
#else
import Logging
#endif

import Chord
import Spacetime
import TransmissionTypes

public class SimulationListenConnection
{
    let networkConnection: TransmissionTypes.Connection
    let logger: Logger?

    fileprivate var reads: [UUID: Read] = [:]
    fileprivate var writes: [UUID: Write] = [:]
    fileprivate var closes: [UUID: Close] = [:]

    public init(_ networkConnection: TransmissionTypes.Connection, logger: Logger?)
    {
        self.networkConnection = networkConnection
        self.logger = logger
    }

    public func read(request: NetworkListenReadRequest, channel: BlockingQueue<Event>)
    {
        let read = Read(logger: self.logger, simulationConnection: self, networkConnection: self.networkConnection, request: request, events: channel)
        self.reads[read.uuid] = read
    }

    public func write(request: NetworkListenWriteRequest, channel: BlockingQueue<Event>)
    {
        let write = Write(logger: self.logger, simulationConnection: self, networkConnection: self.networkConnection, request: request, events: channel)
        self.writes[write.uuid] = write
    }

    public func close(request: NetworkListenCloseRequest, state: NetworkListenModule, channel: BlockingQueue<Event>)
    {
        let close = Close(logger: self.logger, simulationConnection: self, networkConnection: self.networkConnection, state: state, request: request, events: channel)
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
    let logger: Logger?

    public init(logger: Logger?, simulationConnection: SimulationListenConnection, networkConnection: TransmissionTypes.Connection, request: NetworkListenReadRequest, events: BlockingQueue<Event>)
    {
        self.logger = logger
        self.simulationConnection = simulationConnection
        self.networkConnection = networkConnection
        self.request = request
        self.events = events

        let uuid = self.uuid
        
        let timeoutTime: DispatchTime = DispatchTime.now() + .seconds(10) // nanosecond precision
        logAThing(logger: nil, logMessage: "/n/n⏰ SimulationListenConnection: Read starting timeout.")
        
        let timeoutLock = DispatchSemaphore(value: 0)

        let readTask = Task
        {
            defer
            {
                simulationConnection.reads.removeValue(forKey: uuid)
                timeoutLock.signal()
            }
            
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
                    return

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
                    return

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
                    return
            }
        }
        
        
        let readTaskResultStatus = timeoutLock.wait(timeout: timeoutTime)
        logAThing(logger: nil, logMessage: "⏰ SimulationListenConnection: Read timeout complete.\n\n")
        
        switch readTaskResultStatus
        {
            case .success:
                logAThing(logger: nil, logMessage: "Spacetime read task complete!")
            case .timedOut:
                logAThing(logger: nil, logMessage: "Spacetime read task resulted in a timeout!")
                let failure = Failure(request.id)
                print(failure.description)
                events.enqueue(element: failure)
                return
        }
    }
}

fileprivate struct Write
{
    let logger: Logger?
    let simulationConnection: SimulationListenConnection
    let networkConnection: TransmissionTypes.Connection
    let request: NetworkListenWriteRequest
    let events: BlockingQueue<Event>
    let queue = DispatchQueue(label: "SimulationConnection.Write")
    let uuid = UUID()

    public init(logger: Logger?, simulationConnection: SimulationListenConnection, networkConnection: TransmissionTypes.Connection, request: NetworkListenWriteRequest, events: BlockingQueue<Event>)
    {
        self.logger = logger
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
    let logger: Logger?
    let simulationConnection: SimulationListenConnection
    let networkConnection: TransmissionTypes.Connection
    let request: NetworkListenCloseRequest
    let state: NetworkListenModule
    let events: BlockingQueue<Event>
    let queue = DispatchQueue(label: "SimulationConnection.Close")
    let uuid = UUID()

    public init(logger: Logger?, simulationConnection: SimulationListenConnection, networkConnection: TransmissionTypes.Connection, state: NetworkListenModule, request: NetworkListenCloseRequest, events: BlockingQueue<Event>)
    {
        self.logger = logger
        self.simulationConnection = simulationConnection
        self.networkConnection = networkConnection
        self.state = state
        self.request = request
        self.events = events

        let uuid = self.uuid

        queue.async
        {
            networkConnection.close()

            let response = NetworkListenCloseResponse(request.id, uuid)
            print(response.description)
            events.enqueue(element: response)

            state.connections.removeValue(forKey: uuid)
            simulationConnection.closes.removeValue(forKey: uuid)
        }
    }
}
