//
//  Wallet+RecoveryMethods.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 25/09/26.
//

import CrossmintCommonTypes
import Foundation
import Logger

extension Wallet {

    /// Adds a recovery method to the wallet.
    ///
    /// Solana and Stellar wallets only. A recovery method of the wallet approves the change.
    /// To select it, see ``useRecoveryMethod(_:)``.
    ///
    /// - Parameter method: An email, phone, external wallet or API key signer.
    /// - Returns: The completed ``Transaction``.
    /// - Throws: ``WalletError/recoveryConfigRejected(code:message:)`` with
    ///   ``WalletError/RecoveryConfigCode/notSupportedOnChain`` on an EVM wallet.
    ///
    /// ## Example
    /// ```swift
    /// let transaction = try await wallet.addRecoveryMethod(.email("backup@example.com"))
    /// ```
    @discardableResult
    public func addRecoveryMethod(_ method: SignerConfig) async throws(WalletError) -> Transaction {
        Logger.smartWallet.info(LogEvents.walletAddRecoveryMethodStart)
        do {
            try assertRecoveryMethodChangesSupported()
            let recoveryMethod = try recoveryMethodData(for: method)
            let approver = try await recoveryMethodApprover()
            onTransactionStart?()
            let created = try await smartWalletService.addRecoveryMethod(
                recoveryMethod,
                chainType: chain.chainType,
                approver: approver
            )
            let transaction = try await approveRecoveryMethodChange(created.toDomain())
            recordAddedRecoveryMethod(recoveryMethod)
            Logger.smartWallet.info(LogEvents.walletAddRecoveryMethodSuccess, attributes: [
                "transactionId": transaction.id
            ])
            return transaction
        } catch {
            Logger.smartWallet.error(LogEvents.walletAddRecoveryMethodError, attributes: [
                "error": "\(error)"
            ])
            throw error
        }
    }

    /// Removes a recovery method from the wallet.
    ///
    /// Solana and Stellar wallets only. A different recovery method of the wallet approves the change.
    /// To select it, see ``useRecoveryMethod(_:)``. If you selected the removed recovery method, the SDK
    /// clears the selection.
    ///
    /// To remove a signer that you added with ``addSigner(_:)``, use ``removeSigner(locator:)``.
    ///
    /// - Parameter locator: The recovery method to remove.
    /// - Returns: The completed ``Transaction``.
    /// - Throws: ``WalletError/recoveryConfigRejected(code:message:)`` with one of these codes:
    ///   - ``WalletError/RecoveryConfigCode/notSupportedOnChain`` on an EVM wallet.
    ///   - ``WalletError/RecoveryConfigCode/lastSigner`` if the wallet has no other recovery method.
    ///
    /// ## Example
    /// ```swift
    /// let transaction = try await wallet.removeRecoveryMethod(locator: .email("old@example.com"))
    /// ```
    @discardableResult
    public func removeRecoveryMethod(locator: SignerLocator) async throws(WalletError) -> Transaction {
        Logger.smartWallet.info(LogEvents.walletRemoveRecoveryMethodStart, attributes: [
            "locator": locator.value
        ])
        do {
            try assertRecoveryMethodChangesSupported()
            let approver = try await recoveryMethodApprover()
            onTransactionStart?()
            let created = try await smartWalletService.removeRecoveryMethod(
                locator,
                chainType: chain.chainType,
                approver: approver
            )
            let transaction = try await approveRecoveryMethodChange(created.toDomain())
            recordRemovedRecoveryMethod(locator)
            Logger.smartWallet.info(LogEvents.walletRemoveRecoveryMethodSuccess, attributes: [
                "locator": locator.value,
                "transactionId": transaction.id
            ])
            return transaction
        } catch {
            Logger.smartWallet.error(LogEvents.walletRemoveRecoveryMethodError, attributes: [
                "locator": locator.value,
                "error": "\(error)"
            ])
            throw error
        }
    }

    /// Selects the recovery method that approves changes to signers and recovery methods.
    ///
    /// The signer for transactions and messages does not change. To change it, use ``useSigner(_:)``.
    ///
    /// If you do not select a recovery method, the SDK uses one of these:
    /// 1. The only recovery method of the wallet.
    /// 2. The active signer, if it is a recovery method.
    ///
    /// If neither applies, the change fails with ``WalletError/RecoveryConfigCode/signerRequired``.
    ///
    /// - Parameter method: An email, phone or API key recovery method of the wallet.
    /// - Throws: ``WalletError/recoveryConfigRejected(code:message:)`` with
    ///   ``WalletError/RecoveryConfigCode/invalidConfig`` if `method` is not in ``recoveryMethods``,
    ///   or ``WalletError/walletGeneric(_:)`` for a different signer type.
    ///
    /// ## Example
    /// ```swift
    /// try await wallet.useRecoveryMethod(.phone("+14155552671"))
    /// let transaction = try await wallet.removeRecoveryMethod(locator: .email("old@example.com"))
    /// ```
    public func useRecoveryMethod(_ method: SignerConfig) async throws(WalletError) {
        Logger.smartWallet.info(LogEvents.walletUseRecoveryMethodStart)
        do {
            let locator = try recoveryMethodLocator(of: method)
            let signer = try await recoveryMethodSigner(for: method)
            selectedRecoveryMethod = RecoveryApprover(signer: signer, locator: locator)
            Logger.smartWallet.info(LogEvents.walletUseRecoveryMethodSuccess, attributes: [
                "locator": locator.value
            ])
        } catch {
            Logger.smartWallet.error(LogEvents.walletUseRecoveryMethodError, attributes: [
                "error": "\(error)"
            ])
            throw error
        }
    }

    private func recoveryMethodLocator(of method: SignerConfig) throws(WalletError) -> SignerLocator {
        let knownLocators = config.recoveryMethods.map(\.locator)
        guard let locator = method.locator, knownLocators.contains(locator.value) else {
            throw .recoveryConfigRejected(
                code: .invalidConfig,
                message: "This signer is not a recovery method of the wallet. "
                    + "Recovery methods: \(knownLocators.joined(separator: ", "))"
            )
        }
        return locator
    }

    private func recoveryMethodSigner(for method: SignerConfig) async throws(WalletError) -> any Signer {
        let signer: (any Signer)?
        switch method {
        case .email(let email):
            signer = await SignerFactory.email(email, chainType: chain.chainType)
        case .phone(let phone, let channel):
            signer = await SignerFactory.phone(phone, channel: channel, chainType: chain.chainType)
        case .apiKey:
            signer = config.recoverySigner(ofType: ApiKeySignerData.self).map { ApiKeySigner(adminSigner: $0) }
        case .externalWallet, .device, .passkey:
            throw .walletGeneric("Only an email, phone or API key recovery method can approve changes from the SDK.")
        }
        guard let signer else { throw .invalidChain(chain: chain) }
        return signer
    }

    private func assertRecoveryMethodChangesSupported() throws(WalletError) {
        guard chain.chainType == .solana || chain.chainType == .stellar else {
            throw .recoveryConfigRejected(
                code: .notSupportedOnChain,
                message: "Adding and removing recovery methods is not supported on \(chain.name) yet. "
                    + "It is available on Solana and Stellar."
            )
        }
    }

    private func recoveryMethodData(for signer: SignerConfig) throws(WalletError) -> any AdminSignerData {
        switch signer {
        case .email(let email):
            return EmailSignerData(email: email)
        case .phone(let phone, _):
            return PhoneSignerData(phone: phone)
        case .externalWallet(let address):
            return ExternalWalletSignerData(address: address)
        case .apiKey:
            return ApiKeySignerData()
        case .device, .passkey:
            throw .walletGeneric(
                "A recovery method must be an email, phone, external wallet or API key signer."
            )
        }
    }

    private func recoveryMethodApprover() async throws(WalletError) -> SignerLocator {
        if let selected = try await authorizingRecovery().locator {
            return selected
        }
        return try SignerLocator(from: config.recovery.locator)
    }

    private func approveRecoveryMethodChange(_ transaction: Transaction) async throws(WalletError) -> Transaction {
        let completed: Transaction?
        do {
            completed = try await signAndPollWhilePending(transaction)
        } catch {
            if case .serviceError(let serviceError) = error {
                throw .serviceError(serviceError)
            }
            throw .walletGeneric(error.message)
        }
        guard let completed, completed.status == .success else {
            throw .walletGeneric("The recovery method transaction \(transaction.id) did not succeed.")
        }
        return completed
    }

    private func recordAddedRecoveryMethod(_ recoveryMethod: any AdminSignerData) {
        let known = config.recoveryMethods.contains { $0.locator == recoveryMethod.locator }
        guard !known else { return }
        config = WalletConfig(
            recovery: config.recovery,
            others: Array(config.recoveryMethods.dropFirst()) + [recoveryMethod]
        )
    }

    private func recordRemovedRecoveryMethod(_ locator: SignerLocator) {
        if selectedRecoveryMethod?.locator == locator {
            selectedRecoveryMethod = nil
        }
        let remaining = config.recoveryMethods.filter { $0.locator != locator.value }
        guard let first = remaining.first else { return }
        config = WalletConfig(recovery: first, others: Array(remaining.dropFirst()))
    }
}
