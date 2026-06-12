import CrossmintCommonTypes
import DeviceSigner
import Foundation
import Logger

final class DeviceSignerService: Sendable {
    private let smartWalletService: SmartWalletService
    private let chainType: ChainType
    private let chainName: String
    private let address: String
    private let registrationService: SignerRegistrationService

    init(
        smartWalletService: SmartWalletService,
        chainType: ChainType,
        chainName: String,
        address: String
    ) {
        self.smartWalletService = smartWalletService
        self.chainType = chainType
        self.chainName = chainName
        self.address = address
        self.registrationService = SignerRegistrationService(
            smartWalletService: smartWalletService,
            chainType: chainType,
            chainName: chainName
        )
    }

    func register(storage: any DeviceSignerKeyStorage, signer: any Signer) async throws(WalletError) {
        Logger.smartWallet.info(LogEvents.walletRegisterDeviceSignerStart)
        let publicKeyBase64 = try await generatePendingKey(in: storage)
        let registration = try await submitRegistration(of: publicKeyBase64, storage: storage)
        try await approveRegistration(registration, signer: signer, publicKeyBase64: publicKeyBase64, storage: storage)
        try await persistKey(publicKeyBase64, in: storage)
        Logger.smartWallet.info(LogEvents.walletRegisterDeviceSignerSuccess)
    }

    private func generatePendingKey(in storage: any DeviceSignerKeyStorage) async throws(WalletError) -> String {
        do {
            let publicKeyBase64 = try await storage.generateKey(address: nil)
            Logger.smartWallet.info(LogEvents.walletRegisterDeviceSignerKeyGenerated)
            return publicKeyBase64
        } catch {
            Logger.smartWallet.error(LogEvents.walletRegisterDeviceSignerError, attributes: ["error": "\(error)"])
            throw WalletError.walletGeneric("Failed to generate device key: \(error)")
        }
    }

    private func submitRegistration(
        of publicKeyBase64: String,
        storage: any DeviceSignerKeyStorage
    ) async throws(WalletError) -> AddDelegatedSignerResponse {
        let entry: DelegatedSignerEntry
        do {
            entry = try makeDelegatedSignerEntry(publicKeyBase64: publicKeyBase64)
        } catch {
            try? await storage.deletePendingKey(publicKeyBase64: publicKeyBase64)
            Logger.smartWallet.error(LogEvents.walletRegisterDeviceSignerError, attributes: ["error": "\(error)"])
            throw error
        }
        do {
            return try await smartWalletService.addSigner(entry, chainType: chainType, chainName: chainName)
        } catch {
            try? await storage.deletePendingKey(publicKeyBase64: publicKeyBase64)
            Logger.smartWallet.error(LogEvents.walletRegisterDeviceSignerError, attributes: ["error": "\(error)"])
            if case .deviceSignerNotSupported = error {
                throw error
            }
            throw WalletError.walletGeneric("Failed to register device signer: \(error)")
        }
    }

    private func approveRegistration(
        _ registration: AddDelegatedSignerResponse,
        signer: any Signer,
        publicKeyBase64: String,
        storage: any DeviceSignerKeyStorage
    ) async throws(WalletError) {
        let chainEntry = registration.chains?[chainName]
        let pendingApprovalId = chainEntry?.status == "awaiting-approval" ? chainEntry?.id : registration.transaction?.id
        if let pendingApprovalId {
            Logger.smartWallet.info(LogEvents.walletRegisterDeviceSignerAwaitingApproval, attributes: [
                "approvalId": pendingApprovalId
            ])
        }
        do {
            try await registrationService.approveIfNeeded(registration: registration, signer: signer)
            if let pendingApprovalId {
                Logger.smartWallet.info(LogEvents.walletRegisterDeviceSignerApproved, attributes: [
                    "approvalId": pendingApprovalId
                ])
            }
        } catch {
            try? await storage.deletePendingKey(publicKeyBase64: publicKeyBase64)
            Logger.smartWallet.error(LogEvents.walletRegisterDeviceSignerError, attributes: ["error": "\(error)"])
            throw error
        }
    }

    private func persistKey(_ publicKeyBase64: String, in storage: any DeviceSignerKeyStorage) async throws(WalletError) {
        do {
            try await storage.mapAddressToKey(address: address, publicKeyBase64: publicKeyBase64)
        } catch {
            Logger.smartWallet.error(LogEvents.walletRegisterDeviceSignerError, attributes: ["error": "\(error)"])
            throw WalletError.walletGeneric("Failed to persist device key: \(error)")
        }
    }

    func locator(for storage: any DeviceSignerKeyStorage) async -> String? {
        guard let publicKeyBase64 = await storage.getKey(address: address),
              let rawKey = Data(base64Encoded: publicKeyBase64),
              rawKey.count == 65, rawKey[0] == 0x04 else { return nil }
        return "device:\(publicKeyBase64)"
    }

    func ensureRegistered(storage: any DeviceSignerKeyStorage, signer: any Signer) async throws(WalletError) {
        guard await storage.getKey(address: address) == nil else { return }
        Logger.smartWallet.info(LogEvents.walletAddDelegatedSignerStart, attributes: ["address": address])
        do {
            try await register(storage: storage, signer: signer)
            Logger.smartWallet.info(LogEvents.walletAddDelegatedSignerSuccess, attributes: ["address": address])
        } catch {
            Logger.smartWallet.warn(LogEvents.walletAddDelegatedSignerError, attributes: ["error": "\(error)"])
            if case .deviceSignerNotSupported = error {
                throw error
            }
        }
    }

    func buildSignRequest(
        signerLocator: String,
        message: String,
        storage: any DeviceSignerKeyStorage
    ) async throws(DeviceSignerError) -> SignRequestApi {
        let rAndS = try await storage.signMessage(address: address, message: message)
        return SignRequestApi(approvals: [
            .device(signer: signerLocator, signature: .init(r: rAndS.r, s: rAndS.s))
        ])
    }

    private func makeDelegatedSignerEntry(publicKeyBase64: String) throws(WalletError) -> DelegatedSignerEntry {
        guard let rawPublicKey = Data(base64Encoded: publicKeyBase64),
              rawPublicKey.count == 65, rawPublicKey[0] == 0x04 else {
            throw WalletError.walletGeneric("Invalid device signer public key")
        }
        return DelegatedSignerEntry(signer: "device:\(publicKeyBase64)")
    }

}
