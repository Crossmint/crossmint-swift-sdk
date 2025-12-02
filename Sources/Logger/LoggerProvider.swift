//
//  LoggerProvider.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 2/12/25.
//

import Foundation

protocol LoggerProvider: Sendable {
    func debug(_ message: String)
    func error(_ message: String)
    func info(_ message: String)
    func warn(_ message: String)
}
