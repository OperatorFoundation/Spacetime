//
//  Universe.swift
//
//
//  Created by Dr. Brandon Wiley on 2/3/22.
//

import Foundation
#if os(macOS) || os(iOS)
import os.log
#else
import Logging
#endif

import Chord
import Spacetime
import SwiftQueue

open class Universe
{
    public var logger: Logger

    let effects: BlockingQueue<Effect>
    let events: BlockingQueue<Event>
    let lock: DispatchSemaphore = DispatchSemaphore(value: 1)

    var channels = ThreadSafeDictionary<UUID, BlockingQueue<Event>>()

    public init(effects: BlockingQueue<Effect>, events: BlockingQueue<Event>, logger: Logger?)
    {
        self.effects = effects
        self.events = events
        
        if let providedLogger = logger
        {
            self.logger = providedLogger
        }
        else
        {
            #if os(macOS) || os(iOS)
            self.logger = Logger(subsystem: "org.OperatorFoundation.SpacetimeLogger", category: "Universe")
            #else
            self.logger = Logger(label: "org.OperatorFoundation.SpacetimeLogger")
            #endif
        }

        let queue = DispatchQueue(label: "distributeEvents")
        queue.async
        {
            self.distributeEvents()
        }
    }

    public func run() throws
    {
        try self.main()
    }

    open func main() throws
    {
    }

    public func processEffect(_ effect: Effect) -> Event
    {
        let channel = BlockingQueue<Event>()

        self.lock.wait()

        self.channels[effect.id] = channel

        self.lock.signal()

        self.effects.enqueue(element: effect)

        let result = channel.dequeue()

        return result
    }

    open func processEvent(_ event: Event)
    {
        logAThing(logger: self.logger, logMessage: "🛑 Process Event on Universe, but this just returns. Event: \(event.module)")
        return
    }

    func distributeEvents()
    {
        while true
        {
            let event = self.events.dequeue()
            
            if let id = event.effectId
            {
                defer { self.lock.signal() }
                self.lock.wait()

                guard let channel = self.channels[id] else
                {
                    continue
                }

                channel.enqueue(element: event)

                self.channels.removeValue(forKey: id)
            }
            else
            {
                self.processEvent(event)
            }
        }
    }
}
