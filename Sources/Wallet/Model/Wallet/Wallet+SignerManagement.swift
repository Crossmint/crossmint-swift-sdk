import CrossmintCommonTypes
import CryptoKit
import DeviceSigner
import Foundation
import Logger
import Web

extension Wallet {

    // MARK: - Public API

    /// Returns whether this wallet needs recovery on the current device.
    ///
    /// A wallet needs recovery when a device signer is configured but the signing key
    /// for this wallet is not present on the current device. Call ``recover()`` to re-register.
    ///
    /// - Note: This method awaits the background signer-initialization task that runs
    ///   at wallet creation, so the first call may take a moment on slow networks.
    public func needsRecovery() async -> Bool {
        await signerInitializationTask?.value
        return _needsRecovery
    }

    /// Registers a new signer on this wallet.
    ///
    /// Currently supports `.device` signers only. For other types, use the Crossmint dashboard.
    ///
    /// - Parameter config: The signer to add.
    /// - Throws: ``WalletError`` if registration fails.
    public func addSigner(_ config: SignerConfig) async throws(WalletError) {
        Logger.smartWallet.info(LogEvents.walletAddSignerStart)
        do {
            switch config {
            case .device(let options):
                let storage = deviceSignerKeyStorage ?? makeDeviceSignerStorage(options: options)
                try await registerDeviceSigner(storage: storage)
                deviceSignerKeyStorage = storage
            default:
                throw WalletError.walletGeneric("addSigner only supports .device signers via this method")
            }
            Logger.smartWallet.info(LogEvents.walletAddSignerSuccess)
        } catch {
            Logger.smartWallet.error(LogEvents.walletAddSignerError, attributes: ["error": "\(error)"])
            throw error as? WalletError ?? .walletGeneric(error.localizedDescription)
        }
    }

    /// Re-registers the device signer on this device.
    ///
    /// Call this when ``needsRecovery()`` returns `true` — i.e. the wallet has a device signer
    /// registered but the private key is missing on the current device. This generates a new key,
    /// registers it with Crossmint, and awaits approval from the existing admin signer.
    ///
    /// - Throws: ``WalletError`` if recovery fails or there is no device signer configured.
    public func recover() async throws(WalletError) {
        Logger.smartWallet.info(LogEvents.walletRecoverStart)
        await signerInitializationTask?.value
        guard !_deviceSignerApproved else {
            Logger.smartWallet.info(LogEvents.walletRecoverSkipped)
            return
        }
        guard let storage = deviceSignerKeyStorage else {
            let error = WalletError.walletGeneric("No device signer configured on this wallet")
            Logger.smartWallet.error(LogEvents.walletRecoverError, attributes: ["error": "\(error)"])
            throw error
        }
        do {
            try await registerDeviceSigner(storage: storage)
            Logger.smartWallet.info(LogEvents.walletRecoverSuccess)
        } catch {
            Logger.smartWallet.error(LogEvents.walletRecoverError, attributes: ["error": "\(error)"])
            throw error as? WalletError ?? .walletGeneric(error.localizedDescription)
        }
    }

    internal func preAuthIfNeeded() async throws(WalletError) {
        await signerInitializationTask?.value
        if _needsRecovery {
            try await recover()
        }
    }

    /// Sets the active signer used for subsequent wallet operations.
    ///
    /// After calling this method, send and sign operations will use the specified signer
    /// instead of the default admin signer. The signer must already be registered on this
    /// wallet — use ``addSigner(_:)`` to register a new one first.
    ///
    /// - Parameter config: The signer to activate.
    /// - Throws: ``WalletError/signerNotRegistered(_:)`` if the signer is not registered on this wallet.
    public func useSigner(_ config: SignerConfig) async throws(WalletError) {
        switch config {
        case .device(let options):
            try await activateDeviceSigner(options: options)
        case .email(let email):
            let locator = "email:\(email)"
            guard await signerIsRegistered(locator) else { throw .signerNotRegistered(locator) }
            let newSigner: any Signer = await MainActor.run { makeEmailSigner(email: email) }
            activeSigner = newSigner
            activeSignerLocator = locator
        case .passkey(let name, let host):
            try await activatePasskeySigner(name: name, host: host)
        case .apiKey:
            let locator = "api-key:api-key"
            guard await signerIsRegistered(locator) else { throw .signerNotRegistered(locator) }
            activeSigner = ApiKeySigner()
            activeSignerLocator = locator
        }
    }

    // MARK: - Internal

    internal func initDefaultSigner() async {
        guard deviceSignerKeyStorage != nil else { return }

        switch initialDelegatedSigners.count {
        case 0:
            // Device signer was configured but none was registered — recovery needed
            _needsRecovery = true
        case 1:
            guard let locator = initialDelegatedSigners[0].locator,
                  locator.hasPrefix("device:"),
                  let storage = deviceSignerKeyStorage else { return }
            if await storage.getKey(address: address) != nil {
                _deviceSignerApproved = true
            } else {
                _needsRecovery = true
            }
        default:
            // Multiple delegated signers — user must call useSigner to select one
            break
        }
    }

    // MARK: - Private helpers

    private func activateDeviceSigner(options: DeviceSignerOptions) async throws(WalletError) {
        let storage = deviceSignerKeyStorage ?? makeDeviceSignerStorage(options: options)
        guard await storage.getKey(address: address) != nil else {
            throw .walletGeneric("No device key found for this wallet on this device. Call recover() first.")
        }
        deviceSignerKeyStorage = storage
        guard let locator = await deviceSignerLocator() else {
            throw .walletGeneric("Failed to compute device signer locator")
        }
        activeSignerLocator = locator
        _deviceSignerApproved = true
    }

    private func activatePasskeySigner(name: String, host: String) async throws(WalletError) {
        let walletModel: WalletApiModel
        do {
            walletModel = try await smartWalletService.getWallet(GetMeWalletRequest(chainType: chain.chainType))
        } catch {
            throw .walletGeneric("Failed to fetch wallet config")
        }

        let passkeyLocator = walletModel.config.delegatedSigners?
            .compactMap(\.locator)
            .first(where: { $0.hasPrefix("passkey:") })

        let locator: String
        if let delegatedLocator = passkeyLocator {
            locator = delegatedLocator
        } else if config.adminSigner is PasskeySignerData {
            locator = config.adminSigner.locator
        } else {
            throw .signerNotRegistered("passkey:\(name)")
        }

        let credentialId = String(locator.dropFirst("passkey:".count))
        let passkeyData = PasskeySignerData(id: credentialId, name: name, publicKey: .init(x: "0", y: "0"))
        let passkeySigner = PasskeySigner(name: name, host: host)
        _ = await passkeySigner.updateAdminSigner(passkeyData)
        activeSigner = passkeySigner
        activeSignerLocator = locator
    }

    @MainActor
    internal func makeEmailSigner(email: String) -> any Signer {
        switch chain.chainType {
        case .evm:
            EVMEmailSigner(email: email, crossmintTEE: CrossmintTEE.shared)
        case .solana:
            SolanaEmailSigner(email: email, crossmintTEE: CrossmintTEE.shared)
        case .stellar:
            StellarEmailSigner(email: email, crossmintTEE: CrossmintTEE.shared)
        case .unknown:
            EVMEmailSigner(email: email, crossmintTEE: CrossmintTEE.shared)
        }
    }

    internal func makeDeviceSignerStorage(options: DeviceSignerOptions) -> any DeviceSignerKeyStorage {
        let seStorage = SecureEnclaveKeyStorage(biometricPolicy: options.biometricPolicy)
        if seStorage.isAvailable() {
            return seStorage
        }
        return SoftwareDeviceSignerKeyStorage(biometricPolicy: options.biometricPolicy)
    }

    // MARK: - Device signer registration

    // swiftlint:disable:next function_body_length
    private func registerDeviceSigner(storage: any DeviceSignerKeyStorage) async throws(WalletError) {
        Logger.smartWallet.info(LogEvents.walletRegisterDeviceSignerStart)

        let publicKeyBase64: String
        do {
            publicKeyBase64 = try await storage.generateKey(address: nil)
            Logger.smartWallet.info(LogEvents.walletRegisterDeviceSignerKeyGenerated)
        } catch {
            Logger.smartWallet.error(LogEvents.walletRegisterDeviceSignerError, attributes: ["error": "\(error)"])
            throw .walletGeneric("Failed to generate device key: \(error)")
        }

        let entry: DelegatedSignerEntry
        do {
            entry = try makeDelegatedSignerEntry(publicKeyBase64: publicKeyBase64)
        } catch {
            try? await storage.deletePendingKey(publicKeyBase64: publicKeyBase64)
            Logger.smartWallet.error(LogEvents.walletRegisterDeviceSignerError, attributes: ["error": "\(error)"])
            throw error
        }

        let registration: AddDelegatedSignerResponse
        do {
            registration = try await smartWalletService.addDelegatedSigner(
                entry, chainType: chain.chainType, chainName: chain.name
            )
        } catch {
            try? await storage.deletePendingKey(publicKeyBase64: publicKeyBase64)
            Logger.smartWallet.error(LogEvents.walletRegisterDeviceSignerError, attributes: ["error": "\(error)"])
            throw .walletGeneric("Failed to register device signer: \(error)")
        }

        if let chainEntry = registration.chains?[chain.name],
           chainEntry.status == "awaiting-approval",
           let signatureId = chainEntry.id,
           let pending = chainEntry.approvals?.pending, !pending.isEmpty {
            Logger.smartWallet.info(LogEvents.walletRegisterDeviceSignerAwaitingApproval, attributes: [
                "signatureId": signatureId
            ])
            do {
                try await approveDelegatedSignerRegistration(signatureId: signatureId, pendingApprovals: pending)
                Logger.smartWallet.info(LogEvents.walletRegisterDeviceSignerApproved, attributes: [
                    "signatureId": signatureId
                ])
            } catch {
                try? await storage.deletePendingKey(publicKeyBase64: publicKeyBase64)
                Logger.smartWallet.error(LogEvents.walletRegisterDeviceSignerError, attributes: ["error": "\(error)"])
                throw .walletGeneric("Failed to approve device signer registration: \(error)")
            }
        }

        do {
            try await storage.mapAddressToKey(address: address, publicKeyBase64: publicKeyBase64)
        } catch {
            Logger.smartWallet.error(LogEvents.walletRegisterDeviceSignerError, attributes: ["error": "\(error)"])
            throw .walletGeneric("Failed to persist device key: \(error)")
        }

        _needsRecovery = false
        _deviceSignerApproved = true
        Logger.smartWallet.info(LogEvents.walletRegisterDeviceSignerSuccess)
    }

    private func approveDelegatedSignerRegistration(
        signatureId: String,
        pendingApprovals: [ApprovalEntry]
    ) async throws {
        let updatedSigner = await updateSignerIfRequired()
        try await updatedSigner.initialize(smartWalletService)
        for approval in pendingApprovals {
            let signRequest = SignRequestApi(
                approvals: try await updatedSigner.approvals(
                    withSignature: try await updatedSigner.sign(message: approval.message)
                )
            )
            try await smartWalletService.approveSignature(
                .init(transactionId: signatureId, apiRequest: signRequest, chainType: chain.chainType)
            )
        }
    }

    private func makeDelegatedSignerEntry(publicKeyBase64: String) throws(WalletError) -> DelegatedSignerEntry {
        guard let rawPublicKey = Data(base64Encoded: publicKeyBase64),
              rawPublicKey.count == 65, rawPublicKey[0] == 0x04 else {
            throw .walletGeneric("Invalid device signer public key")
        }
        return DelegatedSignerEntry(signer: "device:\(publicKeyBase64)")
    }
}
