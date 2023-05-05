//
//  LogAThing.swift
//  
//
//  Created by Mafalda on 5/5/23.
//

import Foundation

#if os(macOS) || os(iOS)
import os.log
#else
import Logging
#endif

public func logAThing(logger: Logger?, logMessage: String)
{
    if let aLog = logger
    {
        #if os(macOS) || os(iOS)
        aLog.log("\n🪐 ~* \(logMessage, privacy: .public)\n")
        #else
        aLog.debug("\n🪐 ~* \(logMessage)\n")
        #endif
    }
    else
    {
        print(logMessage)
    }
}
