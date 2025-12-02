//
//  LoggerProvider.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 2/12/25.
//

import Foundation

protocol LoggerProvider {
    func debug(_ message: String, attributes: [String: Encodable]?)
    func error(_ message: String, attributes: [String: Encodable]?)
    func info(_ message: String, attributes: [String: Encodable]?)
    func warn(_ message: String, attributes: [String: Encodable]?)
}
