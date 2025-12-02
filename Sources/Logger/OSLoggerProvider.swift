//
//  OSLoggerProvider.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 2/12/25.
//

import Foundation
import OSLog

public class OSLoggerProvider: LoggerProvider {
    private let osLogger: OSLog
    private let subsystem: String
    
    public init(category: String) {
        self.subsystem = "CrossmintSDK"
        self.osLogger = OSLog(subsystem: subsystem, category: category)
    }
    
    func debug(_ message: String, attributes: [String : any Encodable]?) {
        guard Logger.level == .debug else { return }
        os_log(.debug, log: osLogger, "%{public}@", message)
    }
    
    func error(_ message: String, attributes: [String : any Encodable]?) {
        guard Logger.level != .fault else { return }
        os_log(.error, log: osLogger, "%{public}@", message)
    }
    
    func info(_ message: String, attributes: [String : any Encodable]?) {
        guard [.debug, .info].contains(Logger.level) else { return }
        os_log(.info, log: osLogger, "%{public}@", message)
    }
    
    func warn(_ message: String, attributes: [String : any Encodable]?) {
        guard [.debug, .info, .default].contains(Logger.level) else { return }
        os_log(.default, log: osLogger, "%{public}@", message)
    }
}
