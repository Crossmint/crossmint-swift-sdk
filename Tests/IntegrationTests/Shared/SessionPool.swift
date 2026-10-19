import CrossmintCommonTypes
import Foundation
@testable import Wallet

/// Two users per run: preview throttles the auth routes at 5 requests a minute per project, so each test
/// cannot sign in on its own. Wallets are created once per user and chain; tests fetch their own instance.
actor SessionPool {
    static let shared = SessionPool()

    private var sessions: [String: CryptoWalletSession] = [:]
    private var solanaRecovery: [String: SolanaKeypairSigner] = [:]
    private var createdWallets: Set<String> = []

    func primary() async throws -> CryptoWalletSession { try await session(named: "primary") }
    func secondary() async throws -> CryptoWalletSession { try await session(named: "secondary") }

    /// The user's EVM wallet, created on first use with the user's keypair as recovery.
    func evmWallet(of session: CryptoWalletSession) async throws -> Wallet {
        try await wallet(of: session, chain: IntegrationEnvironment.EVM_CHAIN) {
            try await session.wallets().createWallet(
                chain: IntegrationEnvironment.EVM_CHAIN, recovery: session.keypair, options: nil
            )
        }
    }

    /// The user's Solana wallet, created on first use with an ed25519 external wallet as recovery.
    func solanaWallet(of session: CryptoWalletSession) async throws -> (wallet: Wallet, recovery: SolanaKeypairSigner) {
        let recovery = solanaRecovery[session.address] ?? SolanaKeypairSigner()
        solanaRecovery[session.address] = recovery
        let wallet = try await wallet(of: session, chain: IntegrationEnvironment.SOLANA_CHAIN) {
            try await session.wallets().createWallet(
                chain: IntegrationEnvironment.SOLANA_CHAIN, recovery: recovery, options: nil
            )
        }
        return (wallet, recovery)
    }

    private func session(named name: String) async throws -> CryptoWalletSession {
        if let existing = sessions[name] { return existing }
        let session = try await CryptoWalletSession.start()
        sessions[name] = session
        return session
    }

    private func wallet(
        of session: CryptoWalletSession,
        chain: Chain,
        create: () async throws -> Wallet
    ) async throws -> Wallet {
        let key = "\(session.address):\(chain.name)"
        if !createdWallets.contains(key) {
            _ = try await create()
            createdWallets.insert(key)
        }
        guard let wallet = try await session.wallets().getWallet(chain: chain, options: nil) else {
            throw IntegrationSetupError(
                message: "\(chain.name) wallet for \(session.address) was created but cannot be read back"
            )
        }
        return wallet
    }
}
