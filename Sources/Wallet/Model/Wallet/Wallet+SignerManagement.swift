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
        if SecureEnclave.isAvailable {
            return SecureEnclaveKeyStorage(biometricPolicy: options.biometricPolicy)
        } else {
            return SoftwareDeviceSignerKeyStorage(biometricPolicy: options.biometricPolicy)
        }
    }
}
