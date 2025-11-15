import CrossmintCommonTypes

public enum WalletLocator: Codable, Sendable {
    case address(Address)
    case owner(Owner, ChainType)
    case ownerWithChain(Owner, Chain)
    case externalWallet(Chain, Address)

    public var value: String {
        return switch self {
        case let .address(blockchainAddress):
            blockchainAddress.description
        case let .owner(owner, chainType):
            owner.description + ":\(chainType.rawValue)"
        case let .ownerWithChain(owner, chain):
            owner.description + ":\(chain.name)"
        case let .externalWallet(chain, blockchainAddress):
            "\(chain.name):\(blockchainAddress.description)"
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        self = try WalletLocator(from: value)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.value)
    }

    public init(from locator: String) throws {
        let components = locator.split(separator: ":", maxSplits: 3)

        guard 1 <= components.count && components.count <= 3 else {
            throw WalletError.walletLocatorError(locator)
        }

        if components.count == 1 {
            do {
                let address = try Address(address: locator)
                self = .address(address)
            } catch {
                throw WalletError.walletLocatorError(locator)
            }
        } else if components.count == 2 {
            if let chain = Chain.fromName(String(components[0])) {
                do {
                    let address = try Address(address: String(components[1]))
                    self = .externalWallet(chain, address)
                } catch {
                    throw WalletError.walletLocatorError(locator)
                }
            } else {
                throw WalletError.walletLocatorError(locator)
            }
        } else {
            let chainTypeOrChain = String(components[2])
            let linkedUserLocator = String(components[0]) + ":" + String(components[1])
            let owner = try Owner(from: linkedUserLocator)

            if let walletType = ChainType(rawValue: chainTypeOrChain) {
                self = .owner(owner, walletType)
            } else if let chain = Chain.fromName(chainTypeOrChain) {
                self = .ownerWithChain(owner, chain)
            } else {
                throw WalletError.walletLocatorError(locator)
            }
        }
    }
}
