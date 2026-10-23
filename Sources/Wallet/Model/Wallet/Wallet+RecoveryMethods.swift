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
    /// To change the members or the threshold of a quorum, add a new quorum and then remove the old one.
    ///
    /// - Parameters:
    ///   - method: An email, phone, external wallet or passkey signer, or a quorum of them.
    ///     For a passkey, the SDK shows the system prompt to create a new passkey.
    ///     A Solana wallet does not accept a passkey as a recovery method.
    ///   - signer: The recovery method that approves the change. Use it to name the quorum to approve for
    ///     when the recovery method you selected is a member of more than one quorum.
    ///   - prepareOnly: Pass `true` to create the change without approving it.
    ///     Then approve it with ``approve(transactionId:)``.
    /// - Returns: The completed ``Transaction``. With `prepareOnly`, or while other quorum members must still
    ///   approve, the transaction with the status ``TransactionStatus/awaitingApproval``.
    /// - Throws: ``WalletError/recoveryConfigRejected(code:message:)`` with one of these codes:
    ///   - ``WalletError/RecoveryConfigCode/notSupportedOnChain`` if the wallet is an EVM wallet.
    ///   - ``WalletError/RecoveryConfigCode/signerNotAllowed`` if `method` is a passkey
    ///     and the wallet is a Solana wallet.
    ///
    /// ## Example
    /// ```swift
    /// let transaction = try await wallet.addRecoveryMethod(.email("backup@example.com"))
    ///
    /// let quorum = try await wallet.addRecoveryMethod(
    ///     .quorum(threshold: 2, members: [.email("alice@example.com"), .email("bob@example.com")])
    /// )
    /// ```
    @discardableResult
    public func addRecoveryMethod(
        _ method: SignerConfig,
        signer: SignerLocator? = nil,
        prepareOnly: Bool = false
    ) async throws(WalletError) -> Transaction {
        Logger.smartWallet.info(LogEvents.walletAddRecoveryMethodStart)
        do {
            try assertRecoveryMethodChangesSupported()
            try assertChainAccepts(method)
            let approver = try await recoveryMethodApprover(explicit: signer)
            let recoveryMethod = try await recoveryMethodData(for: method)
            onTransactionStart?()
            let created = try await smartWalletService.addRecoveryMethod(
                recoveryMethod,
                chainType: chain.chainType,
                approver: approver
            )
            if prepareOnly { return created.toDomain() }
            let transaction = try await approveRecoveryMethodChange(created.toDomain())
            if transaction.status == .success, recoveryMethod is QuorumSignerInput {
                await reloadRecoveryMethods()
            } else if transaction.status == .success {
                recordAddedRecoveryMethod(recoveryMethod)
            }
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
    /// - Parameters:
    ///   - locator: The recovery method to remove. To remove a quorum, use ``SignerLocator/quorum(id:)``.
    ///   - signer: The recovery method that approves the change. Use it to name the quorum to approve for
    ///     when the recovery method you selected is a member of more than one quorum.
    ///   - prepareOnly: Pass `true` to create the change without approving it.
    ///     Then approve it with ``approve(transactionId:)``.
    /// - Returns: The completed ``Transaction``. With `prepareOnly`, or while other quorum members must still
    ///   approve, the transaction with the status ``TransactionStatus/awaitingApproval``.
    /// - Throws: ``WalletError/recoveryConfigRejected(code:message:)`` with one of these codes:
    ///   - ``WalletError/RecoveryConfigCode/notSupportedOnChain`` on an EVM wallet.
    ///   - ``WalletError/RecoveryConfigCode/lastSigner`` if the wallet has no other recovery method.
    ///
    /// ## Example
    /// ```swift
    /// let transaction = try await wallet.removeRecoveryMethod(locator: .email("old@example.com"))
    /// ```
    @discardableResult
    public func removeRecoveryMethod(
        locator: SignerLocator,
        signer: SignerLocator? = nil,
        prepareOnly: Bool = false
    ) async throws(WalletError) -> Transaction {
        Logger.smartWallet.info(LogEvents.walletRemoveRecoveryMethodStart, attributes: [
            "locator": locator.value
        ])
        do {
            try assertRecoveryMethodChangesSupported()
            let approver = try await recoveryMethodApprover(explicit: signer)
            onTransactionStart?()
            let created = try await smartWalletService.removeRecoveryMethod(
                locator,
                chainType: chain.chainType,
                approver: approver
            )
            if prepareOnly { return created.toDomain() }
            let transaction = try await approveRecoveryMethodChange(created.toDomain())
            if transaction.status == .success {
                recordRemovedRecoveryMethod(locator)
            }
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
    /// - Parameter method: An email, phone, API key or passkey recovery method of the wallet.
    ///   It can also be a member of a quorum recovery method. Then the member approves for the quorum.
    ///   If it is a member of more than one quorum, name the quorum with the `signer` parameter of each change.
    ///   For a passkey, the SDK selects the passkey in ``recoveryMethods`` that has the `id` you give.
    ///   If `id` is `nil`, the wallet must have only one passkey recovery method.
    ///   The SDK does not create a new passkey.
    /// - Throws: ``WalletError/recoveryConfigRejected(code:message:)`` with
    ///   ``WalletError/RecoveryConfigCode/invalidConfig`` if `method` is not in ``recoveryMethods``,
    ///   or if `method` is a passkey with no `id` and the wallet has more than one passkey recovery method.
    ///   The SDK throws ``WalletError/walletGeneric(_:)`` for a different signer type.
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
        let candidate: String? = switch method {
        case .apiKey: config.recoverySigner(ofType: ApiKeySignerData.self)?.locator
        case .passkey(_, _, let id): try recoveryPasskey(id: id)?.locator
        default: method.locator?.value
        }
        let notRecoveryMethod = WalletError.recoveryConfigRejected(
            code: .invalidConfig,
            message: "This signer is not a recovery method of the wallet."
        )
        guard let candidate, let candidateLocator = try? SignerLocator(from: candidate) else {
            throw notRecoveryMethod
        }
        guard config.canApproveRecoveryChanges(candidateLocator) else { throw notRecoveryMethod }
        return candidateLocator
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
        case .passkey(_, let host, let id):
            signer = try await passkeyRecoverySigner(host: host, id: id)
        case .externalWallet, .device, .quorum:
            throw .walletGeneric(
                "Only an email, phone, API key or passkey recovery method can approve changes from the SDK."
            )
        }
        guard let signer else { throw .invalidChain(chain: chain) }
        return signer
    }

    private func recoveryPasskey(id: String?) throws(WalletError) -> PasskeySignerData? {
        let passkeys = config.recoveryMethods.flatMap { method -> [PasskeySignerData] in
            let quorumMembers = (method as? QuorumSignerData)?.members ?? [method]
            return quorumMembers.compactMap { $0 as? PasskeySignerData }
        }
        if let id {
            return passkeys.first { $0.id == id }
        }
        guard passkeys.count <= 1 else {
            throw .recoveryConfigRejected(
                code: .invalidConfig,
                message: "This wallet has more than one passkey recovery method. "
                    + "Pass the credential ID of the passkey to use in SignerConfig.passkey(name:host:id:)."
            )
        }
        return passkeys.first
    }

    private func passkeyRecoverySigner(host: String, id: String?) async throws(WalletError) -> (any Signer)? {
        guard let passkey = try recoveryPasskey(id: id) else { return nil }
        return await SignerFactory.passkey(passkey, host: host)
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

    private func assertChainAccepts(_ method: SignerConfig) throws(WalletError) {
        guard case .passkey = method, chain.chainType == .solana else { return }
        throw .passkeyRecoveryNotAllowedOnSolana
    }

    private func recoveryMethodData(for signer: SignerConfig) async throws(WalletError) -> any AdminSignerData {
        switch signer {
        case .email(let email):
            return EmailSignerData(email: email)
        case .phone(let phone, _):
            return PhoneSignerData(phone: phone)
        case .externalWallet(let address, _):
            return ExternalWalletSignerData(address: address)
        case .passkey(let name, let host, _):
            return try await signerRegistrationService.createPasskey(name: name, host: host)
        case let .quorum(threshold, members):
            guard !members.isEmpty else {
                throw .recoveryConfigRejected(code: .invalidConfig, message: "The quorum has no members")
            }
            var memberData: [any AdminSignerData] = []
            for member in members {
                memberData.append(try await recoveryMethodData(for: member))
            }
            return QuorumSignerInput(threshold: threshold, members: memberData)
        case .apiKey, .device:
            throw .walletGeneric(
                "A recovery method you add must be an email, phone, external wallet or passkey signer."
            )
        }
    }

    private func recoveryMethodApprover(explicit: SignerLocator?) async throws(WalletError) -> SignerLocator {
        if let selected = try await authorizingRecovery(explicit: explicit).locator {
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
        guard let completed, completed.status == .success || completed.awaitsQuorumMembers else {
            throw .walletGeneric("The recovery method transaction \(transaction.id) did not succeed.")
        }
        return completed
    }

    func reloadRecoveryMethods() async {
        do {
            let model = try await smartWalletService.getWallet(GetMeWalletRequest(chainType: chain.chainType))
            config = model.config.toDomain
            if let selected = selectedRecoveryMethod?.locator, !config.canApproveRecoveryChanges(selected) {
                selectedRecoveryMethod = nil
            }
        } catch {
            Logger.smartWallet.warning(LogEvents.walletRecoveryMethodsReloadError, attributes: [
                "error": "\(error)"
            ])
        }
    }

    private func recordAddedRecoveryMethod(_ recoveryMethod: any AdminSignerData) {
        var methods = config.recoveryMethodsWithStatus
        if let index = methods.firstIndex(where: { $0.signer.locator == recoveryMethod.locator }) {
            methods[index] = RecoveryMethod(signer: methods[index].signer, status: .active)
        } else {
            methods.append(RecoveryMethod(signer: recoveryMethod, status: .active))
        }
        config = WalletConfig(
            recovery: methods[0],
            others: Array(methods.dropFirst()),
            signerQuorums: config.signerQuorums
        )
    }

    private func recordRemovedRecoveryMethod(_ locator: SignerLocator) {
        let remaining = config.recoveryMethodsWithStatus.filter { $0.signer.locator != locator.value }
        if let first = remaining.first {
            config = WalletConfig(
                recovery: first,
                others: Array(remaining.dropFirst()),
                signerQuorums: config.signerQuorums
            )
        }
        if let selected = selectedRecoveryMethod?.locator, !config.canApproveRecoveryChanges(selected) {
            selectedRecoveryMethod = nil
        }
    }
}
