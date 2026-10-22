import CrossmintCommonTypes
import Foundation
import Logger

final class SignerRegistrationService: Sendable {
    private let smartWalletService: SmartWalletService
    private let chainType: ChainType
    private let chainName: String

    init(smartWalletService: SmartWalletService, chainType: ChainType, chainName: String) {
        self.smartWalletService = smartWalletService
        self.chainType = chainType
        self.chainName = chainName
    }

    @discardableResult
    func register(
        _ signer: DelegatedSignerEntry.Signer,
        approver: RecoveryApprover,
        deployImmediately: Bool = true,
        prepareOnly: Bool = false
    ) async throws(WalletError) -> String? {
        let entry = DelegatedSignerEntry(signer: signer)
        let registration = try await smartWalletService.addSigner(
            entry,
            chainType: chainType,
            chainName: chainName,
            deployImmediately: deployImmediately,
            approver: approver.locator
        )
        if !prepareOnly {
            try await approveIfNeeded(registration: registration, signer: approver.signer)
        }
        return pendingTransactionId(in: registration)
    }

    @discardableResult
    func registerPasskey(
        name: String,
        host: String,
        approver: RecoveryApprover,
        deployImmediately: Bool = true,
        prepareOnly: Bool = false
    ) async throws(WalletError) -> String? {
        let passkeyData = try await createPasskey(name: name, host: host)
        let registration = try await smartWalletService.registerTypedSigner(
            passkeyData,
            chainType: chainType,
            chainName: chainName,
            deployImmediately: deployImmediately,
            approver: approver.locator
        )
        if !prepareOnly {
            try await approveIfNeeded(registration: registration, signer: approver.signer)
        }
        return pendingTransactionId(in: registration)
    }

    func pendingTransactionId(in registration: AddDelegatedSignerResponse) -> String? {
        guard case .transaction(let id) = pendingApproval(in: registration) else { return nil }
        return id
    }

    func createPasskey(name: String, host: String) async throws(WalletError) -> PasskeySignerData {
        let passkeySigner = PasskeySigner(name: name, host: host)
        do {
            try await passkeySigner.initialize(smartWalletService)
        } catch {
            if case .passkey(.cancelled) = error {
                throw WalletError.walletGeneric("Passkey registration was cancelled")
            }
            throw WalletError.walletGeneric("Passkey registration failed: \(error)")
        }
        return await passkeySigner.adminSigner
    }

    func approveIfNeeded(registration: AddDelegatedSignerResponse, signer: any Signer) async throws(WalletError) {
        switch pendingApproval(in: registration) {
        case let .signature(signatureId, pending):
            Logger.smartWallet.info(LogEvents.walletAddSignerApprovalRouted, attributes: [
                "route": "signature",
                "id": signatureId
            ])
            try await approveSignatureRegistration(signatureId: signatureId, pending: pending, signer: signer)
        case let .transaction(transactionId):
            Logger.smartWallet.info(LogEvents.walletAddSignerApprovalRouted, attributes: [
                "route": "transaction",
                "id": transactionId
            ])
            try await approveRegistrationTransaction(transactionId: transactionId, signer: signer)
        case .notNeeded:
            Logger.smartWallet.info(LogEvents.walletAddSignerApprovalRouted, attributes: ["route": "none"])
        }
    }

    private enum PendingApproval {
        case signature(id: String, pending: [ApprovalEntry])
        case transaction(id: String)
        case notNeeded
    }

    private func pendingApproval(in registration: AddDelegatedSignerResponse) -> PendingApproval {
        if let chainEntry = registration.chains?[chainName] {
            if chainEntry.awaitsApproval, chainEntry.onChain != nil, let transactionId = chainEntry.id {
                return .transaction(id: transactionId)
            }
            if chainEntry.awaitsApproval,
               let signatureId = chainEntry.id,
               let pending = chainEntry.approvals?.pending, !pending.isEmpty {
                return .signature(id: signatureId, pending: pending)
            }
        }
        if let transaction = registration.transaction {
            return .transaction(id: transaction.id)
        }
        return .notNeeded
    }

    private func approveSignatureRegistration(
        signatureId: String,
        pending: [ApprovalEntry],
        signer: any Signer
    ) async throws(WalletError) {
        do {
            try await signer.initialize(smartWalletService)
            for approval in pending {
                try await smartWalletService.approveSignature(
                    signatureId: signatureId,
                    chainType: chainType,
                    signer: signer,
                    message: approval.message
                )
            }
        } catch {
            throw WalletError.walletGeneric("Failed to approve signer registration: \(error)")
        }
    }

    private func approveRegistrationTransaction(
        transactionId: String,
        signer: any Signer
    ) async throws(WalletError) {
        var waitsOnOtherMembers = false
        do {
            let transaction = try await smartWalletService.transaction(withId: transactionId, chainType: chainType)
            let signerLocator = await signer.locator
            let isSigner = { (approval: Transaction.Approvals.Pending) in
                SignerLocator(orUnknown: approval.signer) == signerLocator
            }
            let openQuorums = (transaction.approvals?.quorums ?? []).filter { $0.remaining > 0 }
            let memberPending = openQuorums.compactMap { $0.pending.first(where: isSigner) }
            waitsOnOtherMembers = openQuorums.contains { $0.remaining > ($0.pending.contains(where: isSigner) ? 1 : 0) }
            let messages = ((transaction.approvals?.pending ?? []) + memberPending).map(\.message)
            if !messages.isEmpty {
                try await sign(messages, transactionId: transactionId, signer: signer)
            }
        } catch {
            throw WalletError.walletGeneric("Failed to approve signer registration: \(error)")
        }
        if waitsOnOtherMembers {
            try await waitForOtherMembers(transactionId: transactionId)
        }
    }

    private func waitForOtherMembers(transactionId: String) async throws(WalletError) {
        while true {
            do {
                try await Task.sleep(nanoseconds: 1_000_000_000)
            } catch {
                throw .walletGeneric("The signer registration was cancelled")
            }
            let status: TransactionStatus
            do {
                status = try await smartWalletService.transaction(withId: transactionId, chainType: chainType).status
            } catch {
                throw .walletGeneric("Failed to read the signer registration: \(error.message)")
            }
            switch status {
            case .success:
                return
            case .failed:
                throw .walletGeneric("The signer registration \(transactionId) did not succeed")
            case .pending, .awaitingApproval:
                continue
            }
        }
    }

    private func sign(_ messages: [String], transactionId: String, signer: any Signer) async throws {
        try await signer.initialize(smartWalletService)
        for message in messages {
            try await smartWalletService.signTransaction(
                transactionId: transactionId,
                chainType: chainType,
                signer: signer,
                message: message
            )
        }
    }
}
