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

    // MARK: - Public API

    /// Adds a recovery method to this wallet.
    ///
    /// Only Solana and Stellar wallets support this operation. A recovery method of the wallet
    /// approves the change. If the wallet has more than one recovery method, call ``useSigner(_:)``
    /// first to select the approving recovery method. The SDK signs the approval and waits for
    /// the transaction to complete. After a successful change, ``recoveryMethods`` includes the
    /// new recovery method.
    ///
    /// - Parameter signer: The signer to add as a recovery method. Use an email, phone,
    ///   external wallet or API key signer.
    /// - Returns: The completed ``Transaction``.
    /// - Throws: ``WalletError/recoveryConfigRejected(code:message:)`` with
    ///   ``WalletError/RecoveryConfigCode/notSupportedOnChain`` on an EVM wallet. The SDK does not
    ///   call Crossmint in this case.
    ///
    /// ## Example
    /// ```swift
    /// let transaction = try await wallet.addRecoveryMethod(.email("backup@example.com"))
    /// print("Added:", transaction.id)
    /// ```
    public func addRecoveryMethod(_ signer: SignerConfig) async throws(WalletError) -> Transaction {
        Logger.smartWallet.info(LogEvents.walletAddRecoveryMethodStart)
        do {
            try assertRecoveryMethodChangesSupported()
            let recoveryMethod = try recoveryMethodData(for: signer)
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

    /// Removes a recovery method from this wallet.
    ///
    /// Only Solana and Stellar wallets support this operation. A different recovery method of the
    /// wallet approves the change. If the wallet has more than one recovery method, call
    /// ``useSigner(_:)`` first to select the approving recovery method. The SDK signs the approval
    /// and waits for the transaction to complete. After a successful change, ``recoveryMethods``
    /// does not include the removed recovery method.
    ///
    /// Use ``removeSigner(locator:)`` for signers that you added with ``addSigner(_:)``.
    ///
    /// - Parameter locator: The locator of the recovery method to remove.
    /// - Returns: The completed ``Transaction``.
    /// - Throws: ``WalletError/recoveryConfigRejected(code:message:)`` with
    ///   ``WalletError/RecoveryConfigCode/notSupportedOnChain`` on an EVM wallet. The SDK does not
    ///   call Crossmint in this case.
    ///
    /// ## Example
    /// ```swift
    /// let transaction = try await wallet.removeRecoveryMethod(locator: .email("old@example.com"))
    /// print("Removed:", transaction.id)
    /// ```
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

    // MARK: - Private helpers

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
        let remaining = config.recoveryMethods.filter { $0.locator != locator.value }
        guard let first = remaining.first else { return }
        config = WalletConfig(recovery: first, others: Array(remaining.dropFirst()))
    }
}
