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
    /// - Parameter config: The signer configuration to register.
    /// - Throws: ``WalletError`` if registration fails.
    public func addSigner(_ config: SignerConfig) async throws(WalletError) {
        Logger.smartWallet.info(LogEvents.walletAddSignerStart)
        await signerInitializationTask?.value
        do {
            switch config {
            case .device:
                let storage = deviceSignerKeyStorage ?? makeDeviceSignerStorage()
                try await registerDeviceSigner(storage: storage)
                deviceSignerKeyStorage = storage
            case .email, .phone, .externalWallet, .apiKey:
                guard let locator = config.locator else { return }
                try await registerLocatorSigner(locator)
            case .passkey(let name, let host):
                try await registerPasskeySigner(name: name, host: host)
            }
            Logger.smartWallet.info(LogEvents.walletAddSignerSuccess)
        } catch {
            Logger.smartWallet.error(LogEvents.walletAddSignerError, attributes: ["error": "\(error)"])
            if case .deviceSignerNotSupported = error {
                _deviceSignerUnsupported = true
                _needsRecovery = false
            }
            throw error
        }
    }

    /// Re-registers the device signer on this device.
    ///
    /// Call this when ``needsRecovery()`` returns `true` — i.e. the wallet has a device signer
    /// registered but the private key is missing on the current device. This generates a new key,
    /// registers it with Crossmint, and awaits approval from the existing admin signer.
    ///
    /// If the wallet's provider does not support device signers, this returns without error
    /// and signing stays on the recovery signer; the rejection is remembered so registration
    /// is not retried for this wallet instance.
    ///
    /// - Throws: ``WalletError`` if recovery fails or there is no device signer configured.
    public func recover() async throws(WalletError) {
        Logger.smartWallet.info(LogEvents.walletRecoverStart)
        await signerInitializationTask?.value
        if _deviceSignerUnsupported {
            Logger.smartWallet.info(LogEvents.walletRecoverSkipped)
            _needsRecovery = false
            return
        }
        guard _needsRecovery else {
            Logger.smartWallet.info(LogEvents.walletRecoverSkipped)
            return
        }
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
            if case .deviceSignerNotSupported = error {
                await fallBackToRecoverySigner(storage: storage)
                return
            }
            Logger.smartWallet.error(LogEvents.walletRecoverError, attributes: ["error": "\(error)"])
            throw error
        }
    }

    private func fallBackToRecoverySigner(storage: any DeviceSignerKeyStorage) async {
        Logger.smartWallet.info(LogEvents.walletRecoverDeviceSignerUnsupported)
        try? await storage.deleteKey(address: address)
        _deviceSignerUnsupported = true
        _needsRecovery = false
    }

    /// Sets the active signer used for subsequent wallet operations.
    ///
    /// After calling this method, send and sign operations will use the specified signer
    /// instead of the default admin signer. The signer must already be registered on this
    /// wallet — use ``addSigner(_:)`` to register a new one first.
    ///
    /// - Parameter config: The signer to activate.
    /// - Throws: ``WalletError/signerNotRegistered(_:)`` if the signer is not registered on this wallet,
    ///   or ``WalletError/deviceSignerNotSupported(_:)`` when selecting `.device` on a wallet whose
    ///   provider rejected device signers.
    public func useSigner(_ config: SignerConfig) async throws(WalletError) {
        switch config {
        case .device:
            try await activateDeviceSigner()
        case .email(let email):
            try await activateEmailSigner(email: email)
        case .phone(let phone):
            try await activatePhoneSigner(phone: phone)
        case .externalWallet(let address):
            try await activateExternalWalletSigner(address: address)
        case .passkey(let name, let host):
            try await activatePasskeySigner(name: name, host: host)
        case .apiKey:
            try await activateApiKeySigner()
        }
    }

    // MARK: - Internal

    internal func updateSignerIfRequired() async -> any Signer {
        var updatedSigner: any Signer = signer
        if let passkey = config.recovery as? PasskeySignerData {
            if let passkeySigner = updatedSigner as? PasskeySigner {
                updatedSigner = await passkeySigner.updateAdminSigner(
                    passkey
                )
            }
        }
        return updatedSigner
    }

    internal func preAuthIfNeeded() async throws(WalletError) {
        await signerInitializationTask?.value
        if _needsRecovery {
            try await recover()
        }
    }

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

    private func activateDeviceSigner() async throws(WalletError) {
        if _deviceSignerUnsupported {
            throw .deviceSignerNotSupported(
                "This wallet's provider does not support device signers. " +
                    "Use the recovery signer or another registered signer instead."
            )
        }
        let storage = deviceSignerKeyStorage ?? makeDeviceSignerStorage()
        guard await storage.getKey(address: address) != nil else {
            throw .walletGeneric("No device key found for this wallet on this device. Call recover() first.")
        }
        deviceSignerKeyStorage = storage
        guard let locator = await deviceSignerService.locator(for: storage) else {
            throw .walletGeneric("Failed to compute device signer locator")
        }
        selectedSignerLocator = locator
        _deviceSignerApproved = true
    }

    private func activateEmailSigner(email: String) async throws(WalletError) {
        let locator = "email:\(email)"
        guard await isLocatorStringRegistered(locator) else { throw .signerNotRegistered(locator) }
        let newSigner: any Signer = await MainActor.run { makeEmailSigner(email: email) }
        selectedSigner = newSigner
        selectedSignerLocator = locator
    }

    private func activatePhoneSigner(phone: String) async throws(WalletError) {
        let locator = "phone:\(phone)"
        guard await isLocatorStringRegistered(locator) else { throw .signerNotRegistered(locator) }
        throw .walletGeneric("Phone OTP signing is not yet supported on iOS.")
    }

    private func activateExternalWalletSigner(address: String) async throws(WalletError) {
        let locator = "external-wallet:\(address)"
        guard await isLocatorStringRegistered(locator) else { throw .signerNotRegistered(locator) }
        throw .walletGeneric("External wallet signers must approve transactions outside of the SDK.")
    }

    private func activateApiKeySigner() async throws(WalletError) {
        let locator = config.recovery.locator
        guard await isLocatorStringRegistered(locator) else { throw .signerNotRegistered(locator) }
        guard let apiKeyData = config.recovery as? ApiKeySignerData else {
            throw .walletGeneric("Recovery signer is not an ApiKeySignerData")
        }
        selectedSigner = ApiKeySigner(adminSigner: apiKeyData)
        selectedSignerLocator = locator
    }

    private func activatePasskeySigner(name: String, host: String) async throws(WalletError) {
        let walletModel: WalletApiModel
        do {
            walletModel = try await smartWalletService.getWallet(GetMeWalletRequest(chainType: chain.chainType))
        } catch {
            throw .walletGeneric("Failed to fetch wallet config")
        }

        let passkeyLocator = walletModel.config.signers?
            .compactMap(\.locator)
            .first(where: { $0.hasPrefix("passkey:") })

        let locator: String
        if let delegatedLocator = passkeyLocator {
            locator = delegatedLocator
        } else if config.recovery is PasskeySignerData {
            locator = config.recovery.locator
        } else {
            throw .signerNotRegistered("passkey:\(name)")
        }

        let credentialId = String(locator.dropFirst("passkey:".count))
        let passkeyData = PasskeySignerData(id: credentialId, name: name, publicKey: .init(x: "0", y: "0"))
        let passkeySigner = PasskeySigner(name: name, host: host)
        _ = await passkeySigner.updateAdminSigner(passkeyData)
        selectedSigner = passkeySigner
        selectedSignerLocator = locator
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

    internal func makeDeviceSignerStorage() -> any DeviceSignerKeyStorage {
        let seStorage = SecureEnclaveKeyStorage()
        if seStorage.isAvailable() {
            return seStorage
        }
        return KeychainKeyStorage()
    }

    // MARK: - Device signer registration

    private func registerDeviceSigner(storage: any DeviceSignerKeyStorage) async throws(WalletError) {
        let signer = await updateSignerIfRequired()
        try await deviceSignerService.register(storage: storage, signer: signer)
        _needsRecovery = false
        _deviceSignerApproved = true
    }

    // MARK: - Locator-based signer registration

    private func registerLocatorSigner(_ locator: String) async throws(WalletError) {
        let adminSigner = await updateSignerIfRequired()
        try await signerRegistrationService.register(locator: locator, signer: adminSigner)
    }

    private func registerPasskeySigner(name: String, host: String) async throws(WalletError) {
        let adminSigner = await updateSignerIfRequired()
        try await signerRegistrationService.registerPasskey(name: name, host: host, adminSigner: adminSigner)
    }
}
