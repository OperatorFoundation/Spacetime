//
//  Simulation.swift
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
import Transmission

public class Simulation
{
    let logger: Logger
    let capabilities: Capabilities
    public let effects: BlockingQueue<Effect> = BlockingQueue<Effect>(name: "Spacetime.effects")
    public let events: BlockingQueue<Event> = BlockingQueue<Event>(name: "Spacetime.events")
    let queue = DispatchQueue(label: "Simulation.handleEvents")
    var userModules: [String: Module] = [:]

    public init(capabilities: Capabilities, userModules: [Module]? = nil, logger: Logger? = nil)
    {
        if let newLog = logger
        {
            self.logger = newLog
        }
        else
        {
            #if os(macOS) || os(iOS)
            self.logger = Logger(subsystem: "org.OperatorFoundation.SpacetimeLogger", category: "Simulation")
            #else
            self.logger = Logger(label: "org.OperatorFoundation.SpacetimeLogger")
            #endif
        }
        
        self.capabilities = capabilities
        
        for builtInModule in BuiltinModules.modules
        {
            builtInModule.value.setLogger(logger: logger)
        }
        
        if let userModules = userModules
        {
            for module in userModules
            {
                self.userModules[module.name()] = module
                module.setLogger(logger: logger)
            }
        }

        self.queue.async
        {
            self.handleEffects()
        }
    }

    func handleEffects()
    {
        while true
        {
            let effect = self.effects.dequeue()
            
            switch effect
            {
                case is Display:
                    skip()

                default:
                    logAThing(logger: logger, logMessage: "\(effect.description)")
            }

            var handled = false

            for (name, module) in BuiltinModules.modules
            {
                if effect.module.lowercased() == name.lowercased() && self.capabilities.hasCapability(effect.module.lowercased())
                {
                    handled = true

                    if let response = module.handleEffect(effect, self.events)
                    {
                        logAThing(logger: logger, logMessage: "\(response.description) ")
                        events.enqueue(element: response)
                    }

                    break
                }
            }

            if handled
            {
                continue
            }

            for (name, module) in self.userModules
            {
                handled = true

                if effect.module == name && self.capabilities.hasCapability(effect.module)
                {
                    if let response = module.handleEffect(effect, self.events)
                    {
                        logAThing(logger: logger, logMessage: "\(response.description) ")
                        events.enqueue(element: response)
                    }

                    break
                }
            }

            if handled
            {
                continue
            }

            let response = Failure(effect.id, file: #file, fileID: #fileID, filePath: #filePath, line: #line, column: #column, function: #function)
            logAThing(logger: logger, logMessage: response.description)
            events.enqueue(element: response)
            continue
        }
    }

    func skip()
    {
        return
    }
}

func logAThing(logger: Logger?, logMessage: String)
{
    if let aLog = logger
    {
        #if os(macOS) || os(iOS)
        aLog.log("\n🪐 \(logMessage, privacy: .public)\n")
        #else
        aLog.debug("\n🪐 \(logMessage)\n")
        #endif
    }
    else
    {
        print(logMessage)
    }
}
