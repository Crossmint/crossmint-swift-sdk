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

    @discardableResult
    func register(
        storage: any DeviceSignerKeyStorage,
        approver: RecoveryApprover,
        deployImmediately: Bool = true,
        prepareOnly: Bool = false
    ) async throws(WalletError) -> PendingDeviceKey? {
        Logger.smartWallet.info(LogEvents.walletRegisterDeviceSignerStart)
        let publicKeyBase64 = try await generatePendingKey(in: storage)
        let registration = try await submitRegistration(
            of: publicKeyBase64,
            storage: storage,
            deployImmediately: deployImmediately,
            approver: approver.locator
        )
        let pending = registrationService.pendingTransactionId(in: registration).map {
            PendingDeviceKey(transactionId: $0, publicKeyBase64: publicKeyBase64, storage: storage)
        }
        guard !prepareOnly else { return pending }
        let awaitsOtherMembers = try await approveRegistration(
            registration,
            signer: approver.signer,
            publicKeyBase64: publicKeyBase64,
            storage: storage
        )
        if awaitsOtherMembers { return pending }
        try await persistKey(publicKeyBase64, in: storage)
        Logger.smartWallet.info(LogEvents.walletRegisterDeviceSignerSuccess)
        return nil
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
        storage: any DeviceSignerKeyStorage,
        deployImmediately: Bool,
        approver: SignerLocator?
    ) async throws(WalletError) -> AddDelegatedSignerResponse {
        let deviceName = await storage.deviceName
        guard let publicKey = DevicePublicKey(publicKeyBase64: publicKeyBase64) else {
            try? await storage.deletePendingKey(publicKeyBase64: publicKeyBase64)
            let error = WalletError.walletGeneric("Invalid device signer public key")
            Logger.smartWallet.error(LogEvents.walletRegisterDeviceSignerError, attributes: ["error": "\(error)"])
            throw error
        }
        let entry = DelegatedSignerEntry(signer: .device(publicKey: publicKey, name: deviceName))
        do {
            return try await smartWalletService.addSigner(
                entry,
                chainType: chainType,
                chainName: chainName,
                deployImmediately: deployImmediately,
                approver: approver
            )
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
    ) async throws(WalletError) -> Bool {
        let chainEntry = registration.chains?[chainName]
        let pendingApprovalId = chainEntry?.awaitsApproval == true ? chainEntry?.id : registration.transaction?.id
        if let pendingApprovalId {
            Logger.smartWallet.info(LogEvents.walletRegisterDeviceSignerAwaitingApproval, attributes: [
                "approvalId": pendingApprovalId
            ])
        }
        do {
            let awaitsOtherMembers = try await registrationService.approveIfNeeded(
                registration: registration,
                signer: signer
            )
            if let pendingApprovalId {
                Logger.smartWallet.info(LogEvents.walletRegisterDeviceSignerApproved, attributes: [
                    "approvalId": pendingApprovalId
                ])
            }
            return awaitsOtherMembers
        } catch {
            try? await storage.deletePendingKey(publicKeyBase64: publicKeyBase64)
            Logger.smartWallet.error(LogEvents.walletRegisterDeviceSignerError, attributes: ["error": "\(error)"])
            throw error
        }
    }

    func persistKey(
        _ publicKeyBase64: String,
        in storage: any DeviceSignerKeyStorage
    ) async throws(WalletError) {
        do {
            try await storage.mapAddressToKey(address: address, publicKeyBase64: publicKeyBase64)
        } catch {
            Logger.smartWallet.error(LogEvents.walletRegisterDeviceSignerError, attributes: ["error": "\(error)"])
            throw WalletError.walletGeneric("Failed to persist device key: \(error)")
        }
    }

    func ensureRegistered(
        storage: any DeviceSignerKeyStorage,
        approver: RecoveryApprover
    ) async throws(WalletError) -> PendingDeviceKey? {
        guard await storage.getKey(address: address) == nil else { return nil }
        Logger.smartWallet.info(LogEvents.walletAddDelegatedSignerStart, attributes: ["address": address])
        do {
            let pending = try await register(storage: storage, approver: approver)
            Logger.smartWallet.info(LogEvents.walletAddDelegatedSignerSuccess, attributes: ["address": address])
            return pending
        } catch {
            Logger.smartWallet.warning(LogEvents.walletAddDelegatedSignerError, attributes: ["error": "\(error)"])
            if case .deviceSignerNotSupported = error {
                throw error
            }
            return nil
        }
    }
}
