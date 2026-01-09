//
//  StellarChain.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 12/22/25.
//

public enum StellarChain: SpecificChain, Equatable {
    public var chain: Chain {
        .stellar
    }

    public var chainType: ChainType {
        .stellar
    }

    public var name: String {
        "stellar"
    }

    public func isValid(isProductionEnvironment: Bool) -> Bool {
        true
    }

    public init?(_ from: String) {
        if from.uppercased() != "STELLAR" {
            return nil
        }
        self = .stellar
    }

    case stellar
}
