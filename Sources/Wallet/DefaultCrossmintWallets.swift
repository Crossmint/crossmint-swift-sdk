import CrossmintCommonTypes
import CrossmintService
import CryptoKit
import DeviceSigner
import Logger
import SecureStorage

public final class DefaultCrossmintWallets: CrossmintWallets, Sendable {
    private let smartWalletService: SmartWalletService
    private let secureWalletStorage: SecureWalletStorage

    public init(
        service: SmartWalletService,
        secureWalletStorage: SecureWalletStorage
    ) {
        self.smartWalletService = service
        self.secureWalletStorage = secureWalletStorage

        Logger.smartWallet.info(LogEvents.sdkInitialized)
    }

    public func getWallet(
        chain: Chain,
        recovery: any Signer,
        options: WalletOptions? = nil
    ) async throws(WalletError) -> Wallet? {
        try assertValid(chain)

        Logger.smartWallet.debug(LogEvents.walletGetStart, attributes: [
            "chain": chain.name,
            "signerType": recovery.signerType.rawValue
        ])

        let deviceSignerStorage = makeDeviceSignerStorage(options: options)
        let walletApiModel: WalletApiModel
        do {
            walletApiModel = try await smartWalletService.getWallet(GetMeWalletRequest(chainType: chain.chainType))
        } catch WalletError.walletNotFound {
            return nil
        }

        Logger.smartWallet.debug(LogEvents.walletGetSuccess, attributes: [
            "chain": chain.name,
            "address": walletApiModel.address
        ])

        if let storage = deviceSignerStorage {
            await assignPendingDeviceSignerKey(storage: storage, walletApiModel: walletApiModel)
        }

        let wallet = try buildWallet(
            from: walletApiModel,
            chain: chain,
            signer: recovery,
            options: options,
            deviceSignerStorage: deviceSignerStorage
        )

        do {
            try await (recovery as? any EmailSigner)?.load()
        } catch {
            Logger.smartWallet.warn(
                """
There was an error initializing the Email signer. \(error.errorDescription)
Review if the .crossmintEnvironmentObject modifier is used as expected.
"""
            )
        }

        return wallet
    }

    public func createWallet(
        chain: Chain,
        recovery: any Signer,
        options: WalletOptions? = nil
    ) async throws(WalletError) -> Wallet {
        try assertValid(chain)

        let deviceSignerStorage = makeDeviceSignerStorage(options: options)
        // Solana skips the eager attach: device-signer support depends on the wallet's
        // provider, only known server-side. The first recover() registers the signer
        // instead, falling back to the recovery signer if the provider rejects it.
        let creationDeviceSignerStorage = chain.chainType == .solana ? nil : deviceSignerStorage
        let walletApiModel = try await createWalletApiModel(
            signer: recovery,
            chainType: chain.chainType,
            walletType: .smart,
            options: options,
            deviceSignerStorage: creationDeviceSignerStorage
        )

        let wallet = try buildWallet(
            from: walletApiModel,
            chain: chain,
            signer: recovery,
            options: options,
            deviceSignerStorage: deviceSignerStorage
        )

        do {
            try await (recovery as? any EmailSigner)?.load()
        } catch {
            Logger.smartWallet.warn(
                """
There was an error initializing the Email signer. \(error.errorDescription)
Review if the .crossmintEnvironmentObject modifier is used as expected.
"""
            )
        }

        return wallet
    }

    private func assertValid(_ chain: Chain) throws(WalletError) {
        guard isValid(chain) else {
            Logger.smartWallet.error(LogEvents.walletFactoryInvalidChain, attributes: [
                "error": "The chain \(chain.name) is not supported for the current environment"
            ])
            throw WalletError.invalidChain(chain: chain)
        }
    }

    private func isValid(_ chain: AnyChain) -> Bool {
        chain.isValid(isProductionEnvironment: smartWalletService.isProductionEnvironment)
    }

    private func initializeSigner(
        _ effectiveSigner: any Signer
    ) async throws(WalletError) {
        do {
            try await effectiveSigner.initialize(smartWalletService)
        } catch {
            if case let .passkey(passkeyError) = error {
                switch passkeyError {
                case .notSupported:
                    throw .walletCreationFailed("Passkeys not supported")
                case .cancelled:
                    throw .walletCreationCancelled
                case .invalidUser:
                    throw .walletCreationFailed("Invalid user")
                case .timedOut:
                    throw .walletCreationFailed("Timeout")
                case .unknown, .requestFailed, .invalidChallenge, .badConfiguration:
                    throw .walletCreationFailed("Error initializing admin signer.")
                }
            }
            throw .walletCreationFailed("Error initializing admin signer.")
        }
    }

    // swiftlint:disable:next function_body_length
    private func createWalletApiModel(
        signer: any Signer,
        chainType: ChainType,
        walletType: WalletType,
        options: WalletOptions?,
        deviceSignerStorage: (any DeviceSignerKeyStorage)? = nil
    ) async throws(WalletError) -> WalletApiModel {
        Logger.smartWallet.debug(LogEvents.walletCreateStart, attributes: [
            "chainType": chainType.rawValue,
            "signerType": signer.signerType.rawValue
        ])

        try await initializeSigner(signer)

        options?.experimentalCallbacks?.onWalletCreationStart()

        var delegatedSigners: [DelegatedSignerEntry]?
        var pendingPublicKeyBase64: String?

        if let storage = deviceSignerStorage {
            do {
                let publicKeyBase64 = try await storage.generateKey(address: nil)
                let entry = try makeDelegatedSignerEntry(publicKeyBase64: publicKeyBase64)
                delegatedSigners = [entry]
                pendingPublicKeyBase64 = publicKeyBase64
                Logger.smartWallet.debug(LogEvents.walletCreateDeviceSignerPrepared, attributes: [
                    "publicKeyBase64Prefix": String(publicKeyBase64.prefix(16))
                ])
            } catch {
                Logger.smartWallet.warn(LogEvents.walletAddDelegatedSignerError, attributes: [
                    "error": "\(error)"
                ])
                // Continue wallet creation without device signer
            }
        } else {
            Logger.smartWallet.debug(LogEvents.walletCreateDeviceSignerSkipped)
        }

        do {
            let walletApiModel = try await smartWalletService.createWallet(
                CreateWalletParams(
                    chainType: chainType,
                    type: walletType,
                    config: .init(adminSigner: await signer.adminSigner, delegatedSigners: delegatedSigners)
                )
            )

            // Map the pending key to the now-known wallet address
            if let storage = deviceSignerStorage, let publicKeyBase64 = pendingPublicKeyBase64 {
                do {
                    try await storage.mapAddressToKey(
                        address: walletApiModel.address,
                        publicKeyBase64: publicKeyBase64
                    )
                } catch {
                    try? await storage.deletePendingKey(publicKeyBase64: publicKeyBase64)
                    Logger.smartWallet.warn(LogEvents.walletAddDelegatedSignerError, attributes: [
                        "error": "\(error)"
                    ])
                }
            }

            let createSigners = walletApiModel.config.signers?.compactMap(\.locator) ?? []
            let delegatedSignerLocators = createSigners.isEmpty ? "none" : createSigners.joined(separator: ", ")
            Logger.smartWallet.debug(LogEvents.walletCreateSuccess, attributes: [
                "chainType": chainType.rawValue,
                "address": walletApiModel.address,
                "delegatedSigners": delegatedSignerLocators
            ])

            return walletApiModel
        } catch {
            Logger.smartWallet.error(LogEvents.walletCreateError, attributes: [
                "chainType": chainType.rawValue,
                "error": "\(error)"
            ])
            throw error
        }
    }

    private func buildWallet(
        from walletApiModel: WalletApiModel,
        chain: Chain,
        signer: any Signer,
        options: WalletOptions?,
        deviceSignerStorage: (any DeviceSignerKeyStorage)?
    ) throws(WalletError) -> Wallet {
        switch walletApiModel.chainType {
        case .evm:
            guard let evmChain: EVMChain = EVMChain(chain.name) else {
                throw WalletError.walletInvalidType("The wallet received is not compatible with EVM")
            }
            return try EVMWallet(
                smartWalletService: smartWalletService,
                signer: signer,
                baseModel: walletApiModel,
                evmChain: evmChain,
                onTransactionStart: options?.experimentalCallbacks?.onTransactionStart,
                deviceSignerKeyStorage: deviceSignerStorage
            )
        case .solana:
            guard let solanaChain: SolanaChain = SolanaChain(chain.name) else {
                throw WalletError.walletInvalidType("The wallet received is not compatible with Solana")
            }
            return try SolanaWallet(
                smartWalletService: smartWalletService,
                signer: signer,
                baseModel: walletApiModel,
                solanaChain: solanaChain,
                onTransactionStart: options?.experimentalCallbacks?.onTransactionStart,
                deviceSignerKeyStorage: deviceSignerStorage
            )
        case .stellar:
            guard let stellarChain: StellarChain = StellarChain(chain.name) else {
                throw WalletError.walletInvalidType("The wallet received is not compatible with Stellar")
            }
            return try StellarWallet(
                smartWalletService: smartWalletService,
                signer: signer,
                baseModel: walletApiModel,
                stellarChain: stellarChain,
                onTransactionStart: options?.experimentalCallbacks?.onTransactionStart,
                deviceSignerKeyStorage: deviceSignerStorage
            )
        case .unknown:
            throw .walletGeneric("Unknown wallet chain: \(chain.name)")
        }
    }

    private func assignPendingDeviceSignerKey(
        storage: any DeviceSignerKeyStorage,
        walletApiModel: WalletApiModel
    ) async {
        let existingPublicKeyBase64 = await storage.getKey(address: walletApiModel.address)
        guard !isDeviceSignerRegistered(existingPublicKeyBase64, in: walletApiModel) else { return }
        guard let deviceSignerPendingAssignment = findMatchingDeviceSignerKey(in: walletApiModel, storage: storage) else { return }

        do {
            try await storage.mapAddressToKey(
                address: walletApiModel.address,
                publicKeyBase64: deviceSignerPendingAssignment
            )
            Logger.smartWallet.info(LogEvents.walletAddDelegatedSignerSuccess, attributes: [
                "address": walletApiModel.address
            ])
        } catch {
            Logger.smartWallet.warn(LogEvents.walletAddDelegatedSignerError, attributes: [
                "error": "\(error)"
            ])
        }
    }

    /// Searches the wallet's delegated signers for a pending device key stored on this device.
    ///
    /// Returns the base64-encoded 65-byte uncompressed public key of the first matching key,
    /// or `nil` if none are found.
    private func findMatchingDeviceSignerKey(
        in wallet: WalletApiModel,
        storage: any DeviceSignerKeyStorage
    ) -> String? {
        guard let signers = wallet.config.signers else { return nil }
        for entry in signers {
            guard let locator = entry.locator, locator.hasPrefix("device:") else { continue }
            let b64 = String(locator.dropFirst("device:".count))
            if storage.hasKey(publicKeyBase64: b64) {
                return b64
            }
        }
        return nil
    }

    private func makeDeviceSignerStorage(options: WalletOptions?) -> (any DeviceSignerKeyStorage)? {
        guard options?.deviceSigner == true else { return nil }
        let seStorage = SecureEnclaveKeyStorage()
        if seStorage.isAvailable() {
            return seStorage
        }
        return KeychainKeyStorage()
    }

    private func isDeviceSignerRegistered(_ publicKeyBase64: String?, in wallet: WalletApiModel) -> Bool {
        guard let keyBase64 = publicKeyBase64,
              let rawKey = Data(base64Encoded: keyBase64),
              rawKey.count == 65, rawKey[0] == 0x04 else {
            return false
        }
        let locator = "device:\(keyBase64)"
        return wallet.config.signers?.contains(where: { $0.locator == locator }) ?? false
    }

    private func makeDelegatedSignerEntry(publicKeyBase64: String) throws(WalletError) -> DelegatedSignerEntry {
        guard let rawPublicKey = Data(base64Encoded: publicKeyBase64),
              rawPublicKey.count == 65, rawPublicKey[0] == 0x04 else {
            throw WalletError.walletCreationFailed("Invalid device signer public key")
        }
        return DelegatedSignerEntry(signer: "device:\(publicKeyBase64)")
    }

    private func approveDelegatedSignerRegistration(
        signatureId: String,
        pendingApprovals: [ApprovalEntry],
        signer: any Signer,
        chainType: ChainType
    ) async throws {
        try await initializeSigner(signer)
        for approval in pendingApprovals {
            let signRequest = SignRequestApi(
                approvals: try await signer.approvals(
                    withSignature: try await signer.sign(message: approval.message)
                )
            )
            try await smartWalletService.approveSignature(
                .init(transactionId: signatureId, apiRequest: signRequest, chainType: chainType)
            )
        }
    }
}
