//
//  DataDogConfig.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 2/12/25.
//

import Foundation

public enum DataDogConfig {
    static let clientToken = "pub946d87ea0c2cc02431c15e9446f776fc"

    private nonisolated(unsafe) static var _environment: String = "production"

    static var environment: String {
        _environment
    }

    public static func configure(environment: String) {
        _environment = environment
    }
}
