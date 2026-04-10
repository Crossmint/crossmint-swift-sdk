//
//  AppState.swift
//  SmartWalletsDemo
//

import CrossmintClient
import Observation

extension Error {
    var userMessage: String {
        if let e = self as? WalletError { return e.errorMessage }
        if let e = self as? TransactionError { return e.errorMessage }
        if let e = self as? SignatureError { return e.errorMessage }
        return localizedDescription
    }
}

@Observable
@MainActor
final class AppState {
    var selectedChain: SupportedChain = .evm
    var balance: Balance?
    var isLoadingBalance: Bool = false
    var isCreatingWallet: Bool = false
    var walletErrorMessage: String?

    // Per-chain state
    private var walletCache: [SupportedChain: Wallet] = [:]
    private var loadingChains: Set<SupportedChain> = []
    private var notFoundChains: Set<SupportedChain> = []
    private var currentEmail: String?

    // Signer selection (shared across Transfer/Signing/Signers)
    private(set) var selectedSignerLocator: String? = nil

    private let sdk: CrossmintSDK = .shared

    // MARK: - Derived

    var wallet: Wallet? { walletCache[selectedChain] }
    var walletNotFound: Bool { notFoundChains.contains(selectedChain) }
    var isLoadingWallet: Bool { loadingChains.contains(selectedChain) }

    var formattedBalance: String {
        guard let balance else { return "—" }
        var parts: [String] = []
        let all = [balance.nativeToken, balance.usdc] + balance.tokens
        for token in all {
            guard let amount = Double(token.amount), amount > 0 else { continue }
            let fractionLength = amount < 0.001 ? 6 : (amount < 1 ? 4 : 2)
            parts.append("\(amount.formatted(.number.precision(.fractionLength(fractionLength)))) \(token.symbol.value.uppercased())")
        }
        return parts.isEmpty ? "No balance" : parts.joined(separator: " · ")
    }

    // MARK: - Public actions

    /// Fetches fresh wallet state for the current chain. Safe to call on pull-to-refresh.
    func loadWallet(email: String) async {
        currentEmail = email
        selectedSignerLocator = nil
        let chain = selectedChain
        guard !loadingChains.contains(chain) else { return }

        notFoundChains.remove(chain)
        balance = nil
        loadingChains.insert(chain)
        walletErrorMessage = nil

        do {
            if let found = try await fetchWallet(chain: chain, email: email) {
                walletCache[chain] = found
                // Only update UI state if still on the same chain
                if chain == selectedChain {
                    await fetchBalance()
                    preloadOtherChains(email: email)
                }
            } else {
                notFoundChains.insert(chain)
                walletCache.removeValue(forKey: chain)
            }
        } catch {
            if chain == selectedChain {
                walletErrorMessage = error.userMessage
            }
        }

        loadingChains.remove(chain)
    }

    func createWallet(email: String) async {
        let chain = selectedChain
        isCreatingWallet = true
        walletErrorMessage = nil

        do {
            let w = try await makeWallet(chain: chain, email: email)
            walletCache[chain] = w
            notFoundChains.remove(chain)
            await fetchBalance()
        } catch {
            walletErrorMessage = error.userMessage
        }

        isCreatingWallet = false
    }

    /// Switches chain without re-fetching if the wallet is already cached.
    func switchChain(_ chain: SupportedChain, email: String) async {
        guard chain != selectedChain else { return }
        selectedChain = chain
        selectedSignerLocator = nil
        walletErrorMessage = nil
        balance = nil

        if walletCache[chain] != nil {
            await fetchBalance()
        } else if !notFoundChains.contains(chain) {
            await loadWallet(email: email)
        }
        // notFoundChains.contains(chain) → show "no wallet" UI immediately, no fetch needed
    }

    /// Re-fetches the current chain's wallet from the API and updates the cache.
    func reloadCurrentWallet() async {
        guard let email = currentEmail else { return }
        let chain = selectedChain
        do {
            if let found = try await fetchWallet(chain: chain, email: email) {
                walletCache[chain] = found
            }
        } catch {
            // Keep showing existing wallet on failure
        }
    }

    /// Selects the given signer locator as active for all wallet operations.
    /// Returns an error message on failure, or nil on success.
    @discardableResult
    func selectSigner(locator: String) async -> String? {
        guard locator != "default-signer", !locator.isEmpty else {
            selectedSignerLocator = nil
            return nil
        }
        guard let wallet = wallet else { return "No wallet available" }
        guard let config = signerConfig(for: locator) else {
            return "This signer type cannot be selected directly"
        }
        do {
            try await wallet.useSigner(config)
            selectedSignerLocator = locator
            return nil
        } catch {
            return error.userMessage
        }
    }

    func fetchBalance() async {
        guard let wallet = walletCache[selectedChain] else { return }
        isLoadingBalance = true
        do {
            balance = try await wallet.balances(selectedChain.balanceCurrencies)
        } catch {
            // Non-critical — keep showing existing balance
        }
        isLoadingBalance = false
    }

    // MARK: - Private

    /// Kicks off background fetches for chains not yet in the cache.
    /// Uses unstructured Tasks (fire-and-forget) since these are not tied to any view lifecycle.
    private func preloadOtherChains(email: String) {
        let all: [SupportedChain] = [.evm, .solana, .stellar]
        for chain in all where chain != selectedChain {
            guard walletCache[chain] == nil,
                  !loadingChains.contains(chain),
                  !notFoundChains.contains(chain) else { continue }

            loadingChains.insert(chain)
            Task {
                do {
                    if let found = try await fetchWallet(chain: chain, email: email) {
                        walletCache[chain] = found
                    } else {
                        notFoundChains.insert(chain)
                    }
                } catch {
                    // Silently ignore — background preload only
                }
                loadingChains.remove(chain)
            }
        }
    }

    private func signerConfig(for locator: String) -> SignerConfig? {
        if locator.hasPrefix("device:") { return .device }
        if locator.hasPrefix("api-key:") { return .apiKey }
        if locator.hasPrefix("email:") { return .email(String(locator.dropFirst("email:".count))) }
        return nil
    }

    private func fetchWallet(chain: SupportedChain, email: String) async throws -> Wallet? {
        switch chain {
        case .evm:
            return try await sdk.crossmintWallets.getWallet(
                chain: EVMChain.baseSepolia,
                recovery: EVMSigners.email(email)
            )
        case .solana:
            return try await sdk.crossmintWallets.getWallet(
                chain: SolanaChain.solana,
                recovery: SolanaSigners.email(email)
            )
        case .stellar:
            return try await sdk.crossmintWallets.getWallet(
                chain: StellarChain.stellar,
                recovery: StellarSigners.email(email)
            )
        }
    }

    private func makeWallet(chain: SupportedChain, email: String) async throws -> Wallet {
        switch chain {
        case .evm:
            return try await sdk.crossmintWallets.createWallet(
                chain: EVMChain.baseSepolia,
                recovery: EVMSigners.email(email)
            )
        case .solana:
            return try await sdk.crossmintWallets.createWallet(
                chain: SolanaChain.solana,
                recovery: SolanaSigners.email(email)
            )
        case .stellar:
            return try await sdk.crossmintWallets.createWallet(
                chain: StellarChain.stellar,
                recovery: StellarSigners.email(email)
            )
        }
    }
}
