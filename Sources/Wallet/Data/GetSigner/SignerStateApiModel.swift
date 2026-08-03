import CrossmintCommonTypes

struct SignerStateApiModel: Decodable {
    struct StatusEntry: Decodable {
        let status: String?
    }

    let locator: String?
    let chains: [String: StatusEntry]?
    let transaction: StatusEntry?
}

extension SignerStateApiModel {
    /// Maps to the domain type, reading status the way each chain family reports it:
    /// Solana/Stellar approve registrations through a transaction, EVM tracks per-chain entries.
    ///
    /// Returns `nil` on EVM when the signer has no registration entry for `chainName`,
    /// so callers can omit signers that were never approved for the wallet's chain.
    func toDomain(chainType: ChainType, chainName: String) -> WalletSigner? {
        guard let locator else { return nil }

        switch chainType {
        case .solana, .stellar:
            return WalletSigner(locator: locator, status: SignerStatus.from(transaction?.status ?? "success"))
        case .evm, .unknown:
            guard let chains, !chains.isEmpty else {
                return WalletSigner(locator: locator, status: .active)
            }
            guard let entry = chains[chainName] else { return nil }
            return WalletSigner(locator: locator, status: SignerStatus.from(entry.status))
        }
    }
}
