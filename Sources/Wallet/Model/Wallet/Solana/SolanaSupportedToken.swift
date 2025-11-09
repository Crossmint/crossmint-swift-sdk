import CrossmintCommonTypes

public enum SolanaSupportedToken: Encodable {
    case usdc
    case sol

    public var asCryptoCurrency: CryptoCurrency {
        switch self {
        case .sol:
            .sol
        case .usdc:
            .usdc
        }
    }

    public var name: String {
        asCryptoCurrency.name
    }

    public static func toSolanaSupportedToken(
        _ cryptoCurrency: CryptoCurrency?
    ) -> SolanaSupportedToken? {
        switch cryptoCurrency {
        case .usdc:
            .usdc
        case .sol:
            .sol
        default:
            nil
        }
    }
}
