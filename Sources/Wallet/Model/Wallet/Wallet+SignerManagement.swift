import CrossmintCommonTypes
import CryptoKit
import DeviceSigner
import Foundation
import Logger

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
        try await registerSigner(config, deployImmediately: true)
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

        let staleDeviceSignerLocator = await findStaleDeviceSignerLocator()

        do {
            try await registerDeviceSigner(storage: storage, approver: try await authorizingRecovery())
            Logger.smartWallet.info(LogEvents.walletRecoverSuccess)
        } catch {
            if case .deviceSignerNotSupported = error {
                await fallBackToRecoverySigner(storage: storage)
                return
            }
            Logger.smartWallet.error(LogEvents.walletRecoverError, attributes: ["error": "\(error)"])
            throw error
        }

        if let staleDeviceSignerLocator {
            await removeStaleDeviceSigner(staleDeviceSignerLocator)
        }
    }

    private func findStaleDeviceSignerLocator() async -> SignerLocator? {
        let currentSigners = (try? await signers()) ?? []
        let deviceLocators = currentSigners
            .map(\.locator)
            .filter(\.isDevice)
        guard deviceLocators.count == 1 else { return nil }
        return deviceLocators[0]
    }

    private func removeStaleDeviceSigner(_ locator: SignerLocator) async {
        do {
            _ = try await removeSigner(locator: locator)
            Logger.smartWallet.info(LogEvents.walletRecoverStaleSignerRemoved, attributes: [
                "signerLocator": locator.value
            ])
        } catch {
            Logger.smartWallet.warning(LogEvents.walletRecoverStaleSignerRemovalFailed, attributes: [
                "signerLocator": locator.value,
                "error": "\(error)"
            ])
        }
    }

    private func fallBackToRecoverySigner(storage: any DeviceSignerKeyStorage) async {
        Logger.smartWallet.info(LogEvents.walletRecoverDeviceSignerUnsupported)
        try? await storage.deleteKey(address: address)
        _deviceSignerUnsupported = true
        _needsRecovery = false
    }

    /// Sets the signer that the wallet uses for the next operations.
    ///
    /// After this call, send and sign operations use this signer, not the default admin signer.
    /// The signer must be on this wallet. To add a new signer, call ``addSigner(_:)`` first.
    ///
    /// - Parameter config: The signer to use.
    /// - Throws:
    ///   - ``WalletError/signerNotRegistered(_:)`` if the signer is not on this wallet.
    ///   - ``WalletError/walletGeneric(_:)`` if `config` is `.externalWallet`.
    ///     To sign with an external wallet, pass an ``ExternalWalletSigner`` to `useSigner(_:)`.
    ///   - ``WalletError/deviceSignerNotSupported(_:)`` if `config` is `.device`
    ///     and the wallet does not support device signers.
    public func useSigner(_ config: SignerConfig) async throws(WalletError) {
        switch config {
        case .device:
            try await activateDeviceSigner()
        case .email(let email):
            try await activateEmailSigner(email: email)
        case .phone(let phone, let channel):
            try await activatePhoneSigner(phone: phone, channel: channel)
        case .externalWallet:
            throw .walletGeneric(
                "To use an external wallet signer, pass an ExternalWalletSigner with an onSign callback to useSigner."
            )
        case .passkey(let name, let host):
            try await activatePasskeySigner(name: name, host: host)
        case .apiKey:
            try await activateApiKeySigner()
        }
    }

    /// Sets the external wallet signer that the wallet uses for the next operations.
    ///
    /// After this call, send and sign operations call `onSign` of `signer` to get each approval.
    /// The external wallet must be a recovery signer of this wallet, or a signer that you added
    /// with ``addSigner(_:)``.
    ///
    /// - Parameter signer: The external wallet signer to use.
    /// - Throws: ``WalletError/signerNotRegistered(_:)`` if the external wallet is not on this wallet.
    public func useSigner(_ signer: ExternalWalletSigner) async throws(WalletError) {
        let locator = SignerLocator.externalWallet(address: signer.adminSigner.address)
        let recoveryMatch = config.recoveryMethods.contains { (try? SignerLocator(from: $0.locator)) == locator }
        if !recoveryMatch {
            guard await signerIsRegistered(locator) else { throw .signerNotRegistered(locator.value) }
        }
        selectedSigner = signer
    }

    // MARK: - Internal

    internal func registerSigner(_ config: SignerConfig, deployImmediately: Bool) async throws(WalletError) {
        Logger.smartWallet.info(LogEvents.walletAddSignerStart, attributes: [
            "deployImmediately": "\(deployImmediately)"
        ])
        await signerInitializationTask?.value
        do {
            let approver = try await authorizingRecovery()
            switch config {
            case .device:
                let storage = deviceSignerKeyStorage ?? .default
                try await registerDeviceSigner(
                    storage: storage,
                    approver: approver,
                    deployImmediately: deployImmediately
                )
                deviceSignerKeyStorage = storage
            case .email, .phone, .externalWallet, .apiKey:
                guard let locator = config.locator else { return }
                try await signerRegistrationService.register(
                    locator: locator,
                    approver: approver,
                    deployImmediately: deployImmediately
                )
            case .passkey(let name, let host):
                try await signerRegistrationService.registerPasskey(
                    name: name,
                    host: host,
                    approver: approver,
                    deployImmediately: deployImmediately
                )
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

    internal func authorizingRecovery() async throws(WalletError) -> RecoveryApprover {
        guard config.recoveryMethods.count > 1 else {
            return RecoveryApprover(signer: try await recoverySigner(), locator: nil)
        }
        let recoveryLocators = config.recoveryMethods.compactMap { try? SignerLocator(from: $0.locator) }
        guard let selectedSigner else {
            let signer = try await recoverySigner()
            let locator = try SignerLocator(from: await signer.adminSigner.locator)
            return RecoveryApprover(signer: signer, locator: locator)
        }
        guard let selected = await selectedSigner.locator,
              recoveryLocators.contains(selected),
              let signer = selectedSigner as? any Signer else {
            let choices = recoveryLocators.map(\.value).joined(separator: ", ")
            throw .recoveryConfigRejected(
                code: .signerRequired,
                message: "Only a recovery signer can add or remove signers. Call useSigner with one of: \(choices)"
            )
        }
        return RecoveryApprover(signer: signer, locator: selected)
    }

    internal func updateSignerIfRequired() async -> (any Signer)? {
        guard let signer else { return nil }
        if let passkey = config.recoverySigner(ofType: PasskeySignerData.self),
           let passkeySigner = signer as? PasskeySigner {
            return await passkeySigner.updateAdminSigner(passkey)
        }
        return signer
    }

    internal func recoverySigner() async throws(WalletError) -> any Signer {
        if let signer = await updateSignerIfRequired() { return signer }
        if let selected = selectedSigner as? any Signer { return selected }
        throw .walletGeneric("No signer is available for this wallet's recovery method. Call useSigner(_:) first.")
    }

    internal func approvalSigner(for rawLocator: String) async throws(SignerError) -> any ApprovalSigner {
        let locator = SignerLocator(orUnknown: rawLocator)
        if let selectedSigner, await selectedSigner.locator == locator {
            return selectedSigner
        }
        if locator.isDevice {
            guard let deviceSigner else { throw .device(.keyNotFound) }
            return deviceSigner
        }
        guard let defaultSigner = await updateSignerIfRequired(),
              await defaultSigner.locator == locator else { throw .invalidSigner }
        return defaultSigner
    }

    internal func selectedSignerLocator() async throws(SignerError) -> SignerLocator? {
        guard let selectedSigner else { return nil }
        guard let locator = await selectedSigner.locator else { throw .device(.keyNotFound) }
        return locator
    }

    internal func makeSignRequest(for locator: String, message: String) async throws(SignerError) -> SignRequestApi {
        let signer = try await approvalSigner(for: locator)
        try await signer.initialize(smartWalletService)
        return SignRequestApi(approvals: try await signer.approvals(for: message))
    }

    internal func preAuthIfNeeded() async throws(WalletError) {
        await signerInitializationTask?.value
        if _needsRecovery {
            try await recover()
        }
    }

    internal func initDefaultSigner(delegatedSigners: [WalletSignerConfigApiModel]) async {
        guard deviceSignerKeyStorage != nil, !_deviceSignerUnsupported else { return }

        switch delegatedSigners.count {
        case 0:
            // Device signer was configured but none was registered — recovery needed
            _needsRecovery = true
        case 1:
            guard case .device = delegatedSigners[0].locator,
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
        let storage = deviceSignerKeyStorage ?? .default
        guard await storage.getKey(address: address) != nil else {
            throw .walletGeneric("No device key found for this wallet on this device. Call recover() first.")
        }
        let deviceSigner = DeviceSigner(storage: storage, address: address)
        guard await deviceSigner.locator != nil else {
            throw .walletGeneric("Failed to compute device signer locator")
        }
        deviceSignerKeyStorage = storage
        selectedSigner = deviceSigner
        _deviceSignerApproved = true
    }

    private func activateEmailSigner(email: String) async throws(WalletError) {
        let locator = SignerLocator.email(email)
        guard await signerIsRegistered(locator) else { throw .signerNotRegistered(locator.value) }
        guard let newSigner = await SignerFactory.email(email, chainType: chain.chainType) else {
            throw .invalidChain(chain: chain)
        }
        selectedSigner = newSigner
    }

    private func activatePhoneSigner(phone: String, channel: OTPDeliveryChannel?) async throws(WalletError) {
        let locator = SignerLocator.phone(phone)
        guard await signerIsRegistered(locator) else { throw .signerNotRegistered(locator.value) }
        guard let newSigner = await SignerFactory.phone(phone, channel: channel, chainType: chain.chainType) else {
            throw .invalidChain(chain: chain)
        }
        selectedSigner = newSigner
    }

    private func activateApiKeySigner() async throws(WalletError) {
        guard let apiKeyData = config.recoverySigner(ofType: ApiKeySignerData.self) else {
            throw .signerNotRegistered(SignerLocator.apiKey().value)
        }
        let locator = try SignerLocator(from: apiKeyData.locator)
        guard await signerIsRegistered(locator) else { throw .signerNotRegistered(locator.value) }
        selectedSigner = ApiKeySigner(adminSigner: apiKeyData)
    }

    private func activatePasskeySigner(name: String, host: String) async throws(WalletError) {
        let walletModel: WalletApiModel
        do {
            walletModel = try await smartWalletService.getWallet(GetMeWalletRequest(chainType: chain.chainType))
        } catch {
            throw .walletGeneric("Failed to fetch wallet config")
        }

        let delegatedPasskeyLocator = walletModel.config.signers?
            .map(\.locator)
            .first(where: \.isPasskey)

        let locator: SignerLocator
        if let delegatedPasskeyLocator {
            locator = delegatedPasskeyLocator
        } else if let recoveryPasskey = config.recoverySigner(ofType: PasskeySignerData.self) {
            locator = try SignerLocator(from: recoveryPasskey.locator)
        } else {
            throw .signerNotRegistered(SignerLocator.passkey(credentialId: name).value)
        }

        guard case .passkey(let credentialId) = locator else {
            throw .walletGeneric("Recovery signer is not a passkey")
        }
        let passkeyData = PasskeySignerData(id: credentialId, name: name, publicKey: .init(x: "0", y: "0"))
        let passkeySigner = PasskeySigner(name: name, host: host)
        _ = await passkeySigner.updateAdminSigner(passkeyData)
        selectedSigner = passkeySigner
    }

    // MARK: - Device signer registration

    private func registerDeviceSigner(
        storage: any DeviceSignerKeyStorage,
        approver: RecoveryApprover,
        deployImmediately: Bool = true
    ) async throws(WalletError) {
        try await deviceSignerService.register(
            storage: storage,
            approver: approver,
            deployImmediately: deployImmediately
        )
        _needsRecovery = false
        _deviceSignerApproved = true
    }

}
