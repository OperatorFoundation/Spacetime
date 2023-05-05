//
//  Listener.swift
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

public class SimulationListener
{
    let networkListener: TransmissionTypes.Listener
    fileprivate var accepts: [UUID: Accept] = [:]
    fileprivate var closes: [UUID: Close] = [:]
    let logger: Logger?

    public init(_ networkListener: TransmissionTypes.Listener, logger: Logger?)
    {
        self.networkListener = networkListener
        self.logger = logger
    }

    public func accept(request: AcceptRequest, state: NetworkListenModule, channel: BlockingQueue<Event>)
    {
        let accept = Accept(logger: self.logger, simulationListener: self, networkListener: self.networkListener, state: state, request: request, events: channel)
        self.accepts[accept.uuid] = accept
    }

    public func close(request: NetworkListenCloseRequest, state: NetworkListenModule, channel: BlockingQueue<Event>)
    {
        let close = Close(logger: self.logger, simulationListener: self, networkListener: self.networkListener, state: state, request: request, events: channel)
        self.closes[close.uuid] = close
    }
}

fileprivate struct Accept
{
    let simulationListener: SimulationListener
    let networkListener: TransmissionTypes.Listener
    let request: AcceptRequest
    let events: BlockingQueue<Event>
    let queue = DispatchQueue(label: "SimulationListener.Accept")
    let response: AcceptResponse? = nil
    let state: NetworkListenModule
    let uuid = UUID()

    public init(logger: Logger?, simulationListener: SimulationListener, networkListener: TransmissionTypes.Listener, state: NetworkListenModule, request: AcceptRequest, events: BlockingQueue<Event>)
    {
        self.simulationListener = simulationListener
        self.networkListener = networkListener
        self.state = state
        self.request = request
        self.events = events

        let uuid = self.uuid

        self.queue.async
        {
            do
            {
                let networkAccepted = try networkListener.accept()
                let accepted = SimulationListenConnection(networkAccepted, logger: logger)
                state.connections[uuid] = accepted
                let response = AcceptResponse(request.id, uuid)
                logAThing(logger: logger, logMessage: "💫 \(response.description) ")
                events.enqueue(element: response)
                simulationListener.accepts.removeValue(forKey: uuid)
            }
            catch
            {
                let response = Failure(request.id)
                logAThing(logger: logger, logMessage: "💫 \(response.description) ")
                events.enqueue(element: response)
                simulationListener.accepts.removeValue(forKey: uuid)
            }
        }
    }
}

fileprivate struct Close
{
    let simulationListener: SimulationListener
    let networkListener: TransmissionTypes.Listener
    let state: NetworkListenModule
    let request: NetworkListenCloseRequest
    let events: BlockingQueue<Event>
    let queue = DispatchQueue(label: "SimulationConnection.Close")
    let uuid = UUID()

    public init(logger: Logger?, simulationListener: SimulationListener, networkListener: TransmissionTypes.Listener, state: NetworkListenModule, request: NetworkListenCloseRequest, events: BlockingQueue<Event>)
    {
        self.simulationListener = simulationListener
        self.networkListener = networkListener
        self.state = state
        self.request = request
        self.events = events

        let uuid = self.uuid

        queue.async
        {
            networkListener.close()

            let response = NetworkListenCloseResponse(request.id, uuid)
            logAThing(logger: logger, logMessage: "💫 \(response.description) ")
            events.enqueue(element: response)

            state.listeners.removeValue(forKey: uuid)
            simulationListener.closes.removeValue(forKey: uuid)
        }
    }
}
