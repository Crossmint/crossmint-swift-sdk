//
//  AppState.swift
//  SmartWalletsDemo
//

import CrossmintClient
import Foundation
import Observation

typealias WalletTransaction = Transaction

extension Error {
    var userMessage: String {
        if let e = self as? WalletError { return e.message }
        if let e = self as? TransactionError { return e.message }
        if let e = self as? SignatureError { return e.message }
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
    private var phoneChannels: [String: OTPDeliveryChannel] = [:]

    var pendingRecovery: [RecoverySignerDraft] = []
    var pendingQuorumThreshold: Int?

    // Signer selection (shared across Transfer/Signing/Signers)
    private(set) var selectedSignerID: String?
    private(set) var signers: [WalletSigner] = []
    private(set) var localDeviceLocator: String?
    private(set) var walletRecoveryLocators: [String] = []
    private var approvingRecovery: [SupportedChain: SignerChoice] = [:]

    private let sdk: CrossmintSDK = .shared

    // MARK: - Derived

    var wallet: Wallet? { walletCache[selectedChain] }
    var walletNotFound: Bool { notFoundChains.contains(selectedChain) }
    var isLoadingWallet: Bool { loadingChains.contains(selectedChain) }
    var recoveryLocators: [String] {
        if wallet != nil { return walletRecoveryLocators }
        return currentEmail.map { ["email:\($0)"] } ?? []
    }
    var approvingRecoveryMethod: SignerChoice? { approvingRecovery[selectedChain] }

    var selectableRecoveryMethods: [SignerChoice] {
        recoveryLocators.flatMap { locator in
            guard let quorum = quorum(for: locator) else { return [SignerChoice(locator: locator, quorum: nil)] }
            return quorum.members.map { SignerChoice(locator: $0.locator, quorum: locator) }
        }
    }

    func recoveryName(for locator: String) -> String? {
        let signer = wallet?.recoveryMethods.first { $0.signer.locator == locator }?.signer
        if let quorum = signer as? QuorumSignerData {
            return "Quorum · \(quorum.threshold) of \(quorum.members.count)"
        }
        return (signer as? PasskeySignerData)?.name
    }

    var hasQuorumRecovery: Bool {
        wallet?.recoveryMethods.contains { $0.signer is QuorumSignerData } ?? false
    }

    func quorum(for locator: String) -> QuorumSignerData? {
        wallet?.recoveryMethods.first { $0.signer.locator == locator }?.signer as? QuorumSignerData
    }

    var formattedBalance: String {
        guard let balance else { return "—" }
        var parts: [String] = []
        let all = [balance.nativeToken, balance.usdc] + balance.tokens
        for token in all {
            guard let amount = Double(token.amount), amount > 0 else { continue }
            let fractionLength = amount < 0.001 ? 6 : (amount < 1 ? 4 : 2)
            let formatted = amount.formatted(.number.precision(.fractionLength(fractionLength)))
            parts.append("\(formatted) \(token.symbol.value.uppercased())")
        }
        return parts.isEmpty ? "No balance" : parts.joined(separator: " · ")
    }

    // MARK: - Public actions

    /// Fetches fresh wallet state for the current chain. Safe to call on pull-to-refresh.
    func loadWallet(email: String) async {
        currentEmail = email
        selectedSignerID = nil
        let chain = selectedChain
        guard !loadingChains.contains(chain) else { return }

        notFoundChains.remove(chain)
        balance = nil
        loadingChains.insert(chain)
        walletErrorMessage = nil

        do {
            if let found = try await fetchWallet(chain: chain) {
                walletCache[chain] = found
                approvingRecovery[chain] = nil
                // Only update UI state if still on the same chain
                if chain == selectedChain {
                    await fetchBalance()
                    await loadSigners()
                    preloadOtherChains()
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
            let w: Wallet
            if chain == .stellar, let threshold = pendingQuorumThreshold {
                w = try await makeQuorumWallet(email: email, otherMembers: pendingRecovery, threshold: threshold)
            } else {
                w = try await makeWallet(chain: chain, email: email, extraRecovery: pendingRecovery)
            }
            pendingRecovery = []
            pendingQuorumThreshold = nil
            walletCache[chain] = w
            approvingRecovery[chain] = nil
            notFoundChains.remove(chain)
            await fetchBalance()
            await loadSigners()
        } catch {
            walletErrorMessage = error.userMessage
        }

        isCreatingWallet = false
    }

    func loadSigners() async {
        walletRecoveryLocators = wallet?.recoveryMethods.map(\.signer.locator) ?? []
        signers = (try? await wallet?.signers()) ?? []
        localDeviceLocator = await wallet?.localDeviceSigner()?.value
        if let approving = approvingRecovery[selectedChain], !selectableRecoveryMethods.contains(approving) {
            approvingRecovery[selectedChain] = nil
        }
        guard selectedSignerID == nil, let choice = firstSelectableChoice() else { return }
        await selectSigner(choice)
    }

    /// Switches chain without re-fetching if the wallet is already cached.
    func switchChain(_ chain: SupportedChain, email: String) async {
        guard chain != selectedChain else { return }
        selectedChain = chain
        pendingRecovery = []
        pendingQuorumThreshold = nil
        selectedSignerID = nil
        signers = []
        localDeviceLocator = nil
        walletRecoveryLocators = []
        walletErrorMessage = nil
        balance = nil

        if walletCache[chain] != nil {
            await fetchBalance()
            await loadSigners()
        } else if !notFoundChains.contains(chain) {
            await loadWallet(email: email)
        }
        // notFoundChains.contains(chain) → show "no wallet" UI immediately, no fetch needed
    }

    /// Re-fetches the current chain's wallet from the API and updates the cache.
    func reloadCurrentWallet() async {
        guard currentEmail != nil else { return }
        let chain = selectedChain
        do {
            if let found = try await fetchWallet(chain: chain) {
                walletCache[chain] = found
                approvingRecovery[chain] = nil
            }
        } catch {
            // Keep showing existing wallet on failure
        }
    }

    /// Records how the user wants a phone signer's OTP delivered, so a later selection can
    /// request the same channel.
    func rememberChannel(_ channel: OTPDeliveryChannel, for locator: String) {
        phoneChannels[locator] = channel
    }

    /// Selects the given signer locator as active for all wallet operations.
    /// Returns an error message on failure, or nil on success.
    @discardableResult
    func selectSigner(_ choice: SignerChoice) async -> String? {
        guard choice.locator != "default-signer", !choice.locator.isEmpty else {
            selectedSignerID = nil
            return nil
        }
        guard let wallet = wallet else { return "No wallet available" }
        guard let config = signerConfig(for: choice.locator) else {
            return "This signer type cannot be selected directly"
        }
        do {
            try await wallet.useSigner(config, quorumLocator: choice.quorumLocator)
            selectedSignerID = choice.id
            return nil
        } catch {
            return error.userMessage
        }
    }

    func addRecoveryMethod(_ config: SignerConfig) async throws -> Transaction? {
        guard let wallet else { return nil }
        let transaction = try await wallet.addRecoveryMethod(config, prepareOnly: hasQuorumRecovery)
        await loadSigners()
        return transaction
    }

    func addRecoveryQuorum(threshold: Int, members: [String]) async throws -> Transaction? {
        try await addRecoveryMethod(.quorum(threshold: threshold, members: members.map(memberConfig)))
    }

    func removeRecoveryMethod(locator: String) async throws -> Transaction? {
        guard let wallet else { return nil }
        let chain = selectedChain
        let transaction = try await wallet.removeRecoveryMethod(
            locator: SignerLocator(from: locator),
            prepareOnly: hasQuorumRecovery
        )
        if transaction.status == .success, approvingRecovery[chain]?.belongs(to: locator) == true {
            approvingRecovery[chain] = nil
        }
        await loadSigners()
        return transaction
    }

    func approve(transactionId: String) async throws -> Transaction? {
        guard let wallet else { return nil }
        return try await wallet.approve(transactionId: transactionId)
    }

    func transaction(id: String) async -> Transaction? {
        try? await wallet?.getTransaction(id: id)
    }

    func useRecoveryMethod(_ choice: SignerChoice) async throws {
        guard let wallet else { return }
        guard let config = signerConfig(for: choice.locator) else {
            throw WalletError.walletGeneric("This recovery method cannot approve changes from the app")
        }
        let chain = selectedChain
        try await wallet.useRecoveryMethod(config, quorumLocator: choice.quorumLocator)
        approvingRecovery[chain] = choice
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
    private func preloadOtherChains() {
        let all: [SupportedChain] = [.evm, .solana, .stellar]
        for chain in all where chain != selectedChain {
            guard walletCache[chain] == nil,
                  !loadingChains.contains(chain),
                  !notFoundChains.contains(chain) else { continue }

            loadingChains.insert(chain)
            Task {
                do {
                    if let found = try await fetchWallet(chain: chain) {
                        walletCache[chain] = found
                        if chain == selectedChain {
                            await fetchBalance()
                            await loadSigners()
                        }
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

    private func firstSelectableChoice() -> SignerChoice? {
        if let recovery = selectableRecoveryMethods.first(where: { signerConfig(for: $0.locator) != nil }) {
            return recovery
        }
        let signer = signers.map(\.locator).first { signerConfig(for: $0) != nil }
        return signer.map { SignerChoice(locator: $0.value, quorum: nil) }
    }

    func signerConfig(for locator: String) -> SignerConfig? {
        (try? SignerLocator(from: locator)).flatMap { signerConfig(for: $0) }
    }

    private func signerConfig(for locator: SignerLocator) -> SignerConfig? {
        switch locator {
        case .device: .device
        case .apiKey: .apiKey
        case .email(let email): .email(email)
        // The channel is per onboarding request and the API never returns it, so a locator
        // alone cannot say how the OTP should be delivered.
        case .phone(let number): .phone(number, channel: phoneChannels[locator.value])
        case .passkey(let id): .passkey(name: "Crossmint Demo", host: passkeyHost, id: id)
        default: nil
        }
    }

    private var passkeyHost: String {
        Bundle.main.object(forInfoDictionaryKey: "PasskeyHost") as? String ?? ""
    }

    private func fetchWallet(chain: SupportedChain) async throws -> Wallet? {
        let options = WalletOptions(deviceSigner: true, passkeyHost: passkeyHost)
        switch chain {
        case .evm:
            return try await sdk.crossmintWallets.getWallet(chain: EVMChain.baseSepolia, options: options)
        case .solana:
            return try await sdk.crossmintWallets.getWallet(chain: SolanaChain.solana, options: options)
        case .stellar:
            return try await sdk.crossmintWallets.getWallet(chain: StellarChain.stellar, options: options)
        }
    }

    private func makeWallet(chain: SupportedChain, email: String) async throws -> Wallet {
        let options = WalletOptions(deviceSigner: true, passkeyHost: passkeyHost)
        switch chain {
        case .evm:
            return try await sdk.crossmintWallets.createWallet(
                chain: EVMChain.baseSepolia,
                recoveryMethods: [.email(email)],
                options: options
            )
        case .solana:
            return try await sdk.crossmintWallets.createWallet(
                chain: SolanaChain.solana,
                recoveryMethods: [.email(email)],
                options: options
            )
        case .stellar:
            return try await sdk.crossmintWallets.createWallet(
                chain: StellarChain.stellar,
                recoveryMethods: [.email(email)],
                options: options
            )
        }
    }

    private func makeWallet(
        chain: SupportedChain,
        email: String,
        extraRecovery: [RecoverySignerDraft]
    ) async throws -> Wallet {
        guard chain.supportsRecoveryList, !extraRecovery.isEmpty else {
            return try await makeWallet(chain: chain, email: email)
        }
        let options = WalletOptions(deviceSigner: true, passkeyHost: passkeyHost)
        switch chain {
        case .evm:
            return try await makeWallet(chain: chain, email: email)
        case .solana:
            return try await sdk.crossmintWallets.createWallet(
                chain: SolanaChain.solana,
                recoveryMethods: [.email(email)] + extraRecovery.map(solanaSigner),
                options: options
            )
        case .stellar:
            return try await sdk.crossmintWallets.createWallet(
                chain: StellarChain.stellar,
                recoveryMethods: [.email(email)] + extraRecovery.map(stellarSigner),
                options: options
            )
        }
    }

    private func makeQuorumWallet(
        email: String,
        otherMembers: [RecoverySignerDraft],
        threshold: Int
    ) async throws -> Wallet {
        let options = WalletOptions(deviceSigner: true, passkeyHost: passkeyHost)
        let members = [StellarSigners.email(email)] + otherMembers.map(stellarSigner)
        return try await sdk.crossmintWallets.createWallet(
            chain: StellarChain.stellar,
            recoveryMethods: [.quorum(threshold: min(threshold, members.count), members: members)],
            options: options
        )
    }

    private func memberConfig(_ value: String) -> SignerConfig {
        value.hasPrefix("+") ? .phone(value, channel: phoneChannels["phone:\(value)"]) : .email(value)
    }

    private func solanaSigner(for draft: RecoverySignerDraft) -> SolanaSigners {
        switch draft.kind {
        case .email(let email): .email(email)
        case .phone(let phone): .phone(phone, channel: phoneChannels[draft.locator])
        case .apiKey: .apiKey
        case .passkey: preconditionFailure("A Solana wallet does not accept a passkey recovery method")
        }
    }

    private func stellarSigner(for draft: RecoverySignerDraft) -> StellarSigners {
        switch draft.kind {
        case .email(let email): .email(email)
        case .phone(let phone): .phone(phone, channel: phoneChannels[draft.locator])
        case .apiKey: .apiKey
        case .passkey(let name): .passkey(name: name, host: passkeyHost)
        }
    }
}
