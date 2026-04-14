import CrossmintCommonTypes
import Foundation

final class SignerRegistrationService {
    private let smartWalletService: SmartWalletService
    private let chainType: ChainType
    private let chainName: String

    init(smartWalletService: SmartWalletService, chainType: ChainType, chainName: String) {
        self.smartWalletService = smartWalletService
        self.chainType = chainType
        self.chainName = chainName
    }

    func register(locator: String, signer: any Signer) async throws(WalletError) {
        let entry = DelegatedSignerEntry(signer: locator)
        let registration = try await smartWalletService.addSigner(entry, chainType: chainType, chainName: chainName)
        try await approveIfNeeded(registration: registration, signer: signer)
    }

    func registerPasskey(name: String, host: String, adminSigner: any Signer) async throws(WalletError) {
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
            chainName: chainName
        )
        try await approveIfNeeded(registration: registration, signer: adminSigner)
    }

    func approveIfNeeded(registration: AddDelegatedSignerResponse, signer: any Signer) async throws(WalletError) {
        guard let chainEntry = registration.chains?[chainName],
              chainEntry.status == "awaiting-approval",
              let signatureId = chainEntry.id,
              let pending = chainEntry.approvals?.pending, !pending.isEmpty
        else { return }

        do {
            try await signer.initialize(smartWalletService)
            for approval in pending {
                let signRequest = SignRequestApi(
                    approvals: try await signer.approvals(
                        withSignature: try await signer.sign(message: approval.message)
                    )
                )
                try await smartWalletService.approveSignature(
                    .init(transactionId: signatureId, apiRequest: signRequest, chainType: chainType)
                )
            }
        } catch {
            throw WalletError.walletGeneric("Failed to approve signer registration: \(error)")
        }
    }
}
