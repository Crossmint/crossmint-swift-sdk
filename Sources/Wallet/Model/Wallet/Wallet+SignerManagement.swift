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
    /// If a quorum must approve the new signer, the SDK approves as the member that you selected
    /// with ``useRecoveryMethod(_:)``. When other members must still approve, the SDK returns the transaction
    /// with the status ``TransactionStatus/awaitingApproval``. The other members approve it with
    /// ``approve(transactionId:)``.
    ///
    /// - Parameters:
    ///   - config: The signer configuration to register.
    ///   - signer: The recovery method that approves the new signer. Use it to name the quorum to approve for
    ///     when the recovery method you selected is a member of more than one quorum.
    ///   - prepareOnly: Pass `true` to create the registration without approving it.
    ///     Then approve it with ``approve(transactionId:)``. Solana and Stellar wallets only.
    /// - Returns: With `prepareOnly`, or while other quorum members must still approve, the transaction
    ///   that adds the signer. Otherwise `nil`.
    /// - Throws: ``WalletError`` if registration fails.
    @discardableResult
    public func addSigner(
        _ config: SignerConfig,
        signer: SignerLocator? = nil,
        prepareOnly: Bool = false
    ) async throws(WalletError) -> Transaction? {
        try await registerSigner(config, deployImmediately: true, approver: signer, prepareOnly: prepareOnly)
    }

    /// Re-registers the device signer on this device.
    ///
    /// Call this when ``needsRecovery()`` returns `true` — i.e. the wallet has a device signer
    /// registered but the private key is missing on the current device. This generates a new key,
    /// registers it with Crossmint, and awaits approval from the existing admin signer.
    ///
    /// If a quorum must approve the device signer and other members must still approve, the SDK returns
    /// the transaction with the status ``TransactionStatus/awaitingApproval``. The other members approve it
    /// with ``approve(transactionId:)``. Until then, ``needsRecovery()`` stays `true`, and a later call
    /// returns the same transaction.
    ///
    /// If the wallet's provider does not support device signers, this returns without error
    /// and signing stays on the recovery signer; the rejection is remembered so registration
    /// is not retried for this wallet instance.
    ///
    /// - Returns: The transaction that adds the device signer while other quorum members must still approve.
    ///   Otherwise `nil`.
    /// - Throws: ``WalletError`` if recovery fails or there is no device signer configured.
    @discardableResult
    public func recover() async throws(WalletError) -> Transaction? {
        let outcome = await recoveryGate.run { [self] () async -> Result<Transaction?, WalletError> in
            do throws(WalletError) {
                return .success(try await recoverOnce())
            } catch {
                return .failure(error)
            }
        }
        return try outcome.get()
    }

    private func recoverOnce() async throws(WalletError) -> Transaction? {
        Logger.smartWallet.info(LogEvents.walletRecoverStart)
        await signerInitializationTask?.value
        if _deviceSignerUnsupported {
            Logger.smartWallet.info(LogEvents.walletRecoverSkipped)
            _needsRecovery = false
            return nil
        }
        guard _needsRecovery, !_deviceSignerApproved else {
            Logger.smartWallet.info(LogEvents.walletRecoverSkipped)
            return nil
        }
        guard let storage = deviceSignerKeyStorage else {
            let error = WalletError.walletGeneric("No device signer configured on this wallet")
            Logger.smartWallet.error(LogEvents.walletRecoverError, attributes: ["error": "\(error)"])
            throw error
        }
        if _deviceKeyLost, await storage.getKey(address: address) != nil {
            Logger.smartWallet.info(LogEvents.walletRecoverDeviceKeyReadable)
            deviceKeyIsUsable()
            return nil
        }
        switch try await pendingDeviceRegistration(storage: storage) {
        case .awaitingApproval(let transaction):
            return transaction
        case .activated:
            Logger.smartWallet.info(LogEvents.walletRecoverSuccess)
            return nil
        case .none:
            return try await registerReplacementDeviceKey(storage: storage)
        }
    }

    private func registerReplacementDeviceKey(
        storage: any DeviceSignerKeyStorage
    ) async throws(WalletError) -> Transaction? {
        let staleDeviceSignerLocator = await findStaleDeviceSignerLocator()

        do {
            let approver = try await authorizingRecovery()
            if let pendingTransactionId = try await registerDeviceSigner(storage: storage, approver: approver) {
                pendingDeviceKey?.replacedSigner = staleDeviceSignerLocator
                return try await preparedTransaction(withId: pendingTransactionId)
            }
            Logger.smartWallet.info(LogEvents.walletRecoverSuccess)
        } catch {
            if case .deviceSignerNotSupported = error {
                await fallBackToRecoverySigner(storage: storage)
                return nil
            }
            Logger.smartWallet.error(LogEvents.walletRecoverError, attributes: ["error": "\(error)"])
            throw error
        }

        if let staleDeviceSignerLocator {
            await removeStaleDeviceSigner(staleDeviceSignerLocator)
        }
        return nil
    }

    private func findStaleDeviceSignerLocator() async -> SignerLocator? {
        let currentSigners = (try? await signers()) ?? []
        let deviceLocators = currentSigners
            .map(\.locator)
            .filter(\.isDevice)
        guard deviceLocators.count == 1 else { return nil }
        return deviceLocators[0]
    }

    func removeStaleDeviceSigner(_ locator: SignerLocator) async {
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

    /// Sets the signer for the send and sign operations of this wallet.
    ///
    /// The signer replaces the admin signer.
    /// The signer must be registered on this wallet.
    /// To register a new signer, call ``addSigner(_:)`` first.
    ///
    /// The signer can also be a member of a quorum recovery method or of a quorum signer.
    /// Then the transactions that you send name the quorum, and the member approves for the quorum.
    /// If the signer is also a signer of the wallet on its own, it sends as itself.
    /// If it is a member of more than one quorum, name the quorum with the `signer` parameter of the call.
    ///
    /// To select the recovery method that approves signer changes, use ``useRecoveryMethod(_:)``.
    ///
    /// - Parameters:
    ///   - config: The signer to use.
    /// - Throws:
    ///   - ``WalletError/signerNotRegistered(_:)`` if the signer is not registered on this wallet.
    ///   - The ``WalletError`` of the failed request if the API does not return the wallet signers.
    ///     The active signer does not change. You can try again.
    ///   - ``WalletError/walletGeneric(_:)`` if `config` is ``SignerConfig/externalWallet(_:onSign:)``
    ///     and `onSign` is `nil`.
    ///   - ``WalletError/walletGeneric(_:)`` if `config` is ``SignerConfig/passkey(name:host:id:)`` with no `id`
    ///     and the wallet has more than one passkey signer.
    ///   - ``WalletError/deviceSignerNotSupported(_:)`` if you select `.device`
    ///     and the wallet provider does not accept device signers.
    public func useSigner(_ config: SignerConfig) async throws(WalletError) {
        switch config {
        case .device:
            try await activateDeviceSigner()
        case .email(let email):
            try await activateEmailSigner(email: email)
        case .phone(let phone, let channel):
            try await activatePhoneSigner(phone: phone, channel: channel)
        case .externalWallet(let address, let onSign):
            try await activateExternalWalletSigner(address: address, onSign: onSign)
        case .passkey(let name, let host, let id):
            try await activatePasskeySigner(name: name, host: host, id: id)
        case .apiKey:
            try await activateApiKeySigner()
        case .quorum:
            throw .walletGeneric("A quorum cannot be the active signer. Pick one of its members.")
        }
    }

    // MARK: - Internal

    internal func registerSigner(
        _ config: SignerConfig,
        deployImmediately: Bool,
        approver explicitApprover: SignerLocator? = nil,
        prepareOnly: Bool = false
    ) async throws(WalletError) -> Transaction? {
        Logger.smartWallet.info(LogEvents.walletAddSignerStart, attributes: [
            "deployImmediately": "\(deployImmediately)"
        ])
        await signerInitializationTask?.value
        do {
            let approver = try await authorizingRecovery(explicit: explicitApprover)
            let pendingTransactionId: String?
            switch config {
            case .device:
                let storage = deviceSignerKeyStorage ?? .default
                pendingTransactionId = try await registerDeviceSigner(
                    storage: storage,
                    approver: approver,
                    deployImmediately: deployImmediately,
                    prepareOnly: prepareOnly
                )
                deviceSignerKeyStorage = storage
            case .email, .phone, .externalWallet, .apiKey, .quorum:
                guard let signer = try DelegatedSignerEntry.Signer.registration(of: config) else { return nil }
                pendingTransactionId = try await signerRegistrationService.register(
                    signer,
                    approver: approver,
                    deployImmediately: deployImmediately,
                    prepareOnly: prepareOnly
                )
            case .passkey(let name, let host, _):
                pendingTransactionId = try await signerRegistrationService.registerPasskey(
                    name: name,
                    host: host,
                    approver: approver,
                    deployImmediately: deployImmediately,
                    prepareOnly: prepareOnly
                )
            }
            if case .quorum = config, !prepareOnly {
                await reloadRecoveryMethods()
            }
            Logger.smartWallet.info(LogEvents.walletAddSignerSuccess)
            guard let pendingTransactionId else { return nil }
            return try await preparedTransaction(withId: pendingTransactionId)
        } catch {
            Logger.smartWallet.error(LogEvents.walletAddSignerError, attributes: ["error": "\(error)"])
            if case .deviceSignerNotSupported = error {
                _deviceSignerUnsupported = true
                _needsRecovery = false
            }
            throw error
        }
    }

    internal func authorizingRecovery(explicit: SignerLocator? = nil) async throws(WalletError) -> RecoveryApprover {
        if let selectedRecoveryMethod, let memberLocator = selectedRecoveryMethod.locator {
            if let explicit {
                return RecoveryApprover(signer: selectedRecoveryMethod.signer, locator: explicit)
            }
            let role = try config.recoveryRole(of: memberLocator, explicit: nil)
            return RecoveryApprover(signer: selectedRecoveryMethod.signer, locator: role)
        }
        guard config.recoveryMethods.count > 1 else {
            return RecoveryApprover(signer: try await recoverySigner(), locator: explicit)
        }
        let activeSigner: (any ApprovalSigner)?
        if let selectedSigner {
            activeSigner = selectedSigner
        } else {
            activeSigner = await updateSignerIfRequired()
        }
        let signerRequired = WalletError.recoveryConfigRejected(
            code: .signerRequired,
            message: "This wallet has several recovery methods, and the active signer is not one of them. "
                + "Call useRecoveryMethod with one of the wallet's recovery methods."
        )
        guard let activeSigner,
              let activeLocator = await activeSigner.locator,
              let signer = activeSigner as? any Signer else {
            throw signerRequired
        }
        let recoveryLocator: SignerLocator?
        if let explicit {
            recoveryLocator = explicit
        } else {
            recoveryLocator = try config.recoveryRole(of: activeLocator, explicit: nil)
        }
        guard let recoveryLocator else { throw signerRequired }
        return RecoveryApprover(signer: signer, locator: recoveryLocator)
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
        if let selectedRecoveryMethod, await selectedRecoveryMethod.signer.locator == locator {
            return selectedRecoveryMethod.signer
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
        guard let locator = await selectedSigner.locator else {
            if selectedSigner is DeviceSigner { markDeviceKeyLost(.keyNotFound) }
            throw .device(.keyNotFound)
        }
        return locator
    }

    internal func makeSignRequest(for locator: String, message: String) async throws(SignerError) -> SignRequestApi {
        do {
            let signer = try await approvalSigner(for: locator)
            try await signer.initialize(smartWalletService)
            return SignRequestApi(approvals: try await signer.approvals(for: message, on: chain.chainType))
        } catch {
            if case .device(let deviceError) = error, deviceError.isKeyLoss {
                markDeviceKeyLost(deviceError)
            }
            throw error
        }
    }

    /// The key this wallet trusted is not usable right now, so the next ``recover()`` (or the next
    /// operation, through `preAuthIfNeeded`) re-registers one, unless the key reads again by then:
    /// a locked device reads as missing too.
    private func markDeviceKeyLost(_ error: DeviceSignerError) {
        Logger.smartWallet.warning(LogEvents.walletDeviceKeyLost, attributes: ["error": "\(error)"])
        _needsRecovery = true
        _deviceSignerApproved = false
        _deviceKeyLost = true
    }

    func deviceKeyIsUsable() {
        _needsRecovery = false
        _deviceSignerApproved = true
        _deviceKeyLost = false
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
        try await requireRegisteredSigner(.email(email))
        guard let newSigner = await SignerFactory.email(email, chainType: chain.chainType) else {
            throw .invalidChain(chain: chain)
        }
        selectedSigner = newSigner
    }

    private func activatePhoneSigner(phone: String, channel: OTPDeliveryChannel?) async throws(WalletError) {
        try await requireRegisteredSigner(.phone(phone))
        guard let newSigner = await SignerFactory.phone(phone, channel: channel, chainType: chain.chainType) else {
            throw .invalidChain(chain: chain)
        }
        selectedSigner = newSigner
    }

    private func activateExternalWalletSigner(
        address: String,
        onSign: (@Sendable (String) async throws -> String)?
    ) async throws(WalletError) {
        guard let onSign else {
            throw .walletGeneric(
                "To sign with an external wallet, pass an onSign callback in SignerConfig.externalWallet."
            )
        }
        try await requireRegisteredSigner(.externalWallet(address: address))
        selectedSigner = ExternalWalletSigner(address: address, onSign: onSign)
    }

    private func activateApiKeySigner() async throws(WalletError) {
        if let apiKeyData = config.recoverySigner(ofType: ApiKeySignerData.self) {
            selectedSigner = ApiKeySigner(adminSigner: apiKeyData)
            return
        }
        try await requireRegisteredSigner(.apiKey())
        selectedSigner = ApiKeySigner(adminSigner: ApiKeySignerData())
    }

    private func activatePasskeySigner(name: String, host: String, id: String?) async throws(WalletError) {
        let credentialId: String
        if let id {
            try await requireRegisteredSigner(.passkey(credentialId: id))
            credentialId = id
        } else {
            credentialId = try await soleRegisteredPasskeyId()
        }
        let passkeyData = PasskeySignerData(id: credentialId, name: name, publicKey: .init(x: "0", y: "0"))
        let passkeySigner = PasskeySigner(name: name, host: host)
        _ = await passkeySigner.updateAdminSigner(passkeyData)
        selectedSigner = passkeySigner
    }

    private func soleRegisteredPasskeyId() async throws(WalletError) -> String {
        let walletModel = try await smartWalletService.getWallet(GetMeWalletRequest(chainType: chain.chainType))
        let delegatedPasskeyIds = (walletModel.config.signers ?? []).compactMap { signer -> String? in
            guard case .passkey(let credentialId) = signer.locator else { return nil }
            return credentialId
        }
        guard delegatedPasskeyIds.count <= 1 else {
            throw .walletGeneric(
                "This wallet has more than one passkey signer. "
                    + "Pass the credential ID of the passkey to use in SignerConfig.passkey(name:host:id:)."
            )
        }
        if let delegatedPasskeyId = delegatedPasskeyIds.first {
            return delegatedPasskeyId
        }
        guard let recoveryPasskey = config.recoverySigner(ofType: PasskeySignerData.self) else {
            throw .signerNotRegistered("passkey")
        }
        return recoveryPasskey.id
    }

    private func requireRegisteredSigner(_ locator: SignerLocator) async throws(WalletError) {
        if config.recoveryLocator(actingFor: locator) != nil { return }
        if !config.quorumLocators(withMember: locator).isEmpty { return }
        if try await fetchSignerRegistration(locator) { return }
        await reloadRecoveryMethods()
        guard !config.quorumLocators(withMember: locator).isEmpty else { throw .signerNotRegistered(locator.value) }
    }

    // MARK: - Device signer registration

    @discardableResult
    private func registerDeviceSigner(
        storage: any DeviceSignerKeyStorage,
        approver: RecoveryApprover,
        deployImmediately: Bool = true,
        prepareOnly: Bool = false
    ) async throws(WalletError) -> String? {
        let pending = try await deviceSignerService.register(
            storage: storage,
            approver: approver,
            deployImmediately: deployImmediately,
            prepareOnly: prepareOnly
        )
        if let pending {
            pendingDeviceKey = pending
            return pending.transactionId
        }
        guard !prepareOnly else { return nil }
        deviceKeyIsUsable()
        return nil
    }

    private func preparedTransaction(withId id: String) async throws(WalletError) -> Transaction {
        do {
            return try await smartWalletService.transaction(withId: id, chainType: chain.chainType)
        } catch {
            throw .walletGeneric("Could not read the prepared transaction \(id): \(error.message)")
        }
    }

}
