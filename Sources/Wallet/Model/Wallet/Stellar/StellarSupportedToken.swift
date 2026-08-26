//
//  StellarSupportedToken.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 12/22/25.
//

import CrossmintCommonTypes

public enum StellarSupportedToken: Encodable {
    case xlm
    case usdxm

    public var asCryptoCurrency: CryptoCurrency {
        switch self {
        case .xlm:
            .xlm
        case .usdxm:
            .usdxm
        }
    }

    public var name: String {
        asCryptoCurrency.name
    }

    public static func toStellarSupportedToken(
        _ cryptoCurrency: CryptoCurrency?
    ) -> StellarSupportedToken? {
        switch cryptoCurrency {
        case .xlm:
            .xlm
        case .usdxm:
            .usdxm
        default:
            nil
        }
    }
}
