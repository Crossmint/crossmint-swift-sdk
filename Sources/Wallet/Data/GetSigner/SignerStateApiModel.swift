import CrossmintCommonTypes

struct SignerStateApiModel: Decodable {
    struct ChainEntry: Decodable {
        let status: String?
    }

    struct TransactionEntry: Decodable {
        let status: String?
    }

    let locator: String?
    let signer: String?
    let chains: [String: ChainEntry]?
    let transaction: TransactionEntry?
}

extension SignerStateApiModel {
    /// Maps to the domain type, reading status the way each chain family reports it:
    /// Solana/Stellar approve registrations through a transaction, EVM tracks per-chain entries.
    ///
    /// Returns `nil` on EVM when the signer has no registration entry for `chainName`,
    /// so callers can omit signers that were never approved for the wallet's chain.
    func toDomain(chainType: ChainType, chainName: String) -> WalletSigner? {
        guard let locator = locator ?? signer else { return nil }

        switch chainType {
        case .solana, .stellar:
            let rawStatus = transaction?.status
            let status = rawStatus.flatMap(SignerStatus.init(rawValue:)) ?? .success
            return WalletSigner(locator: locator, status: status)
        case .evm, .unknown:
            guard let chains, !chains.isEmpty else {
                // No per-chain entries: the signer was registered at wallet creation and is already active
                return WalletSigner(locator: locator, status: .success)
            }
            guard let rawStatus = chains[chainName]?.status,
                  let status = SignerStatus(rawValue: rawStatus) else { return nil }
            return WalletSigner(locator: locator, status: status)
        }
    }
}
