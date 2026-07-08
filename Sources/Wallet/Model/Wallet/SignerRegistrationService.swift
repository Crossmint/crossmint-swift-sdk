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

    func register(
        locator: String,
        signer: any Signer,
        deployImmediately: Bool = true
    ) async throws(WalletError) {
        let entry = DelegatedSignerEntry(signer: locator)
        let registration = try await smartWalletService.addSigner(
            entry,
            chainType: chainType,
            chainName: chainName,
            deployImmediately: deployImmediately
        )
        try await approveIfNeeded(registration: registration, signer: signer)
    }

    func registerPasskey(
        name: String,
        host: String,
        adminSigner: any Signer,
        deployImmediately: Bool = true
    ) async throws(WalletError) {
        let passkeySigner = PasskeySigner(name: name, host: host)
        do {
            try await passkeySigner.initialize(smartWalletService)
        } catch {
            if case .passkey(.cancelled) = error {
                throw WalletError.walletGeneric("Passkey registration was cancelled")
            }
            throw WalletError.walletGeneric("Passkey registration failed: \(error)")
        }

        let passkeyData = await passkeySigner.adminSigner
        let registration = try await smartWalletService.registerTypedSigner(
            passkeyData,
            chainType: chainType,
            chainName: chainName,
            deployImmediately: deployImmediately
        )
        try await approveIfNeeded(registration: registration, signer: adminSigner)
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
        do {
            let transaction = try await smartWalletService.transaction(withId: transactionId, chainType: chainType)
            guard let pending = transaction.approvals?.pending, !pending.isEmpty else { return }
            try await signer.initialize(smartWalletService)
            for approval in pending {
                try await smartWalletService.signTransaction(
                    transactionId: transactionId,
                    chainType: chainType,
                    signer: signer,
                    message: approval.message
                )
            }
        } catch {
            throw WalletError.walletGeneric("Failed to approve signer registration: \(error)")
        }
    }
}
