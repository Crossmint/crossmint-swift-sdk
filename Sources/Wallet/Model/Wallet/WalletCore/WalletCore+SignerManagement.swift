import CrossmintCommonTypes
import DeviceSigner
import Logger
import Web

extension WalletCore {

    // MARK: - Public surface (forwarded from RecoverableWallet conformances)

    func needsRecoveryValue() async -> Bool {
        await ensureSignerInitialized()
        return needsRecovery
    }

    func addSigner(_ config: SignerConfig) async throws(WalletError) {
        Logger.smartWallet.info(LogEvents.walletAddSignerStart)
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
    }

    func useSigner(_ config: SignerConfig) async throws(WalletError) {
        switch config {
        case .device:
            try await activateDeviceSigner()
        case .email(let email):
            try await activateEmailSigner(email: email)
        case .phone:
            throw WalletError.walletGeneric("Phone OTP signing is not yet supported on iOS.")
        case .externalWallet(let walletAddress):
            let signerLocator = "external-wallet:\(walletAddress)"
            guard await signerIsRegistered(signerLocator) else { throw .signerNotRegistered(signerLocator) }
            throw WalletError.walletGeneric("External wallet signers must approve transactions outside of the SDK.")
        case .passkey(let name, let host):
            try await activatePasskeySigner(name: name, host: host)
        case .apiKey:
            try await activateApiKeySigner()
        }
    }

    func recover() async throws(WalletError) {
        Logger.smartWallet.info(LogEvents.walletRecoverStart)
        await ensureSignerInitialized()
        guard needsRecovery, !deviceSignerApproved else {
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
            throw error
        }
    }

    // MARK: - Internal

    func preAuthIfNeeded() async throws(WalletError) {
        await ensureSignerInitialized()
        if needsRecovery { try await recover() }
    }

    private func ensureSignerInitialized() async {
        guard !signerInitialized else { return }
        signerInitialized = true
        await evaluateDeviceSignerState()
    }

    func evaluateDeviceSignerState() async {
        guard deviceSignerKeyStorage != nil else { return }
        switch initialDelegatedSigners.count {
        case 0:
            needsRecovery = true
        case 1:
            guard let locatorValue = initialDelegatedSigners[0].locator,
                  locatorValue.hasPrefix("device:"),
                  let storage = deviceSignerKeyStorage else { return }
            if await storage.getKey(address: address) != nil {
                deviceSignerApproved = true
            } else {
                needsRecovery = true
            }
        default:
            break
        }
    }

    func resolveActiveSigner() async -> any Signer {
        if let selected = selectedSigner { return selected }
        var resolved: any Signer = signer
        if let passkey = config.recovery as? PasskeySignerData, let passkeySigner = resolved as? PasskeySigner {
            resolved = await passkeySigner.updateAdminSigner(passkey)
        }
        return resolved
    }

    func buildSignRequest(signer: any Signer, message: String) async throws -> SignRequestApi {
        let signature = try await signer.sign(message: message)
        let approvals = try await signer.approvals(withSignature: signature)
        return SignRequestApi(approvals: approvals)
    }

    // MARK: - Private helpers

    private func activateDeviceSigner() async throws(WalletError) {
        let storage = deviceSignerKeyStorage ?? makeDeviceSignerStorage()
        guard await storage.getKey(address: address) != nil else {
            throw .walletGeneric("No device key found for this wallet on this device. Call recover() first.")
        }
        deviceSignerKeyStorage = storage
        guard let signerLocator = await deviceSignerService.locator(for: storage) else {
            throw .walletGeneric("Failed to compute device signer locator")
        }
        selectedSignerLocator = signerLocator
        deviceSignerApproved = true
    }

    private func activateEmailSigner(email: String) async throws(WalletError) {
        let signerLocator = "email:\(email)"
        guard await signerIsRegistered(signerLocator) else { throw .signerNotRegistered(signerLocator) }
        let chainType = chain.chainType
        let newSigner: any Signer = await MainActor.run { WalletCore.makeEmailSigner(email: email, chainType: chainType) }
        selectedSigner = newSigner
        selectedSignerLocator = signerLocator
    }

    private func activateApiKeySigner() async throws(WalletError) {
        let signerLocator = self.config.recovery.locator
        guard await signerIsRegistered(signerLocator) else { throw .signerNotRegistered(signerLocator) }
        guard let apiKeyData = self.config.recovery as? ApiKeySignerData else {
            throw .walletGeneric("Recovery signer is not an ApiKeySignerData")
        }
        selectedSigner = ApiKeySigner(adminSigner: apiKeyData)
        selectedSignerLocator = signerLocator
    }

    private func activatePasskeySigner(name: String, host: String) async throws(WalletError) {
        let signerLocator = try await resolvePasskeySignerLocator(name: name)
        let credentialId = String(signerLocator.dropFirst("passkey:".count))
        let passkeyData = PasskeySignerData(id: credentialId, name: name, publicKey: .init(x: "0", y: "0"))
        let passkeySigner = PasskeySigner(name: name, host: host)
        _ = await passkeySigner.updateAdminSigner(passkeyData)
        selectedSigner = passkeySigner
        selectedSignerLocator = signerLocator
    }

    private func resolvePasskeySignerLocator(name: String) async throws(WalletError) -> String {
        let walletModel: WalletApiModel
        do {
            walletModel = try await smartWalletService.getWallet(GetMeWalletRequest(chainType: chain.chainType))
        } catch {
            throw .walletGeneric("Failed to fetch wallet config")
        }
        let delegatedLocator = walletModel.config.signers?
            .compactMap(\.locator)
            .first(where: { $0.hasPrefix("passkey:") })
        if let delegatedLocator { return delegatedLocator }
        if config.recovery is PasskeySignerData { return config.recovery.locator }
        throw .signerNotRegistered("passkey:\(name)")
    }

    private func registerDeviceSigner(storage: any DeviceSignerKeyStorage) async throws(WalletError) {
        let adminSigner = await resolveActiveSigner()
        try await deviceSignerService.register(storage: storage, signer: adminSigner)
        needsRecovery = false
        deviceSignerApproved = true
    }

    private func registerLocatorSigner(_ signerLocator: String) async throws(WalletError) {
        let adminSigner = await resolveActiveSigner()
        try await signerRegistrationService.register(locator: signerLocator, signer: adminSigner)
    }

    private func registerPasskeySigner(name: String, host: String) async throws(WalletError) {
        let adminSigner = await resolveActiveSigner()
        try await signerRegistrationService.registerPasskey(name: name, host: host, adminSigner: adminSigner)
    }

    private func signerIsRegistered(_ signerLocator: String) async -> Bool {
        let walletModel: WalletApiModel
        do {
            walletModel = try await smartWalletService.getWallet(GetMeWalletRequest(chainType: chain.chainType))
        } catch {
            return false
        }
        let delegatedMatch = walletModel.config.signers?.contains(where: { $0.locator == signerLocator }) ?? false
        if delegatedMatch { return true }
        return walletModel.config.recovery.toDomain.locator == signerLocator
    }

    private func makeDeviceSignerStorage() -> any DeviceSignerKeyStorage {
        let seStorage = SecureEnclaveKeyStorage()
        return seStorage.isAvailable() ? seStorage : KeychainKeyStorage()
    }

    @MainActor
    private static func makeEmailSigner(email: String, chainType: ChainType) -> any Signer {
        switch chainType {
        case .evm: return EVMEmailSigner(email: email, crossmintTEE: CrossmintTEE.shared)
        case .solana: return SolanaEmailSigner(email: email, crossmintTEE: CrossmintTEE.shared)
        case .stellar: return StellarEmailSigner(email: email, crossmintTEE: CrossmintTEE.shared)
        case .unknown: return EVMEmailSigner(email: email, crossmintTEE: CrossmintTEE.shared)
        }
    }
}
