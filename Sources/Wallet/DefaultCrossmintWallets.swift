import CrossmintCommonTypes
import CryptoKit
import DeviceSigner
import Logger
import SecureStorage

public final class DefaultCrossmintWallets: CrossmintWallets, Sendable {
    private let smartWalletService: SmartWalletService
    private let secureWalletStorage: SecureWalletStorage
    private let deviceSignerKeyStorage: DeviceSignerKeyStorage

    public init(
        service: SmartWalletService,
        secureWalletStorage: SecureWalletStorage,
        deviceSignerKeyStorage: DeviceSignerKeyStorage
    ) {
        self.smartWalletService = service
        self.secureWalletStorage = secureWalletStorage
        self.deviceSignerKeyStorage = deviceSignerKeyStorage

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

        let deviceSignerStorage = self.deviceSignerStorage(for: options)
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
            Logger.smartWallet.warning(
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

        let deviceSignerStorage = self.deviceSignerStorage(for: options)
        let creation = try await createWalletApiModel(
            signer: recovery,
            chainType: chain.chainType,
            walletType: .smart,
            options: options,
            deviceSignerStorage: deviceSignerStorage
        )

        let wallet = try buildWallet(
            from: creation.model,
            chain: chain,
            signer: recovery,
            options: options,
            deviceSignerStorage: deviceSignerStorage,
            deviceSignerUnsupported: creation.deviceSignerRejected
        )

        do {
            try await (recovery as? any EmailSigner)?.load()
        } catch {
            Logger.smartWallet.warning(
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

    private struct PendingDeviceSigner {
        let entry: DelegatedSignerEntry
        let publicKeyBase64: String
        let storage: any DeviceSignerKeyStorage

        func discard() async {
            try? await storage.deletePendingKey(publicKeyBase64: publicKeyBase64)
        }
    }

    private func createWalletApiModel(
        signer: any Signer,
        chainType: ChainType,
        walletType: WalletType,
        options: WalletOptions?,
        deviceSignerStorage: (any DeviceSignerKeyStorage)? = nil
    ) async throws(WalletError) -> (model: WalletApiModel, deviceSignerRejected: Bool) {
        Logger.smartWallet.debug(LogEvents.walletCreateStart, attributes: [
            "chainType": chainType.rawValue,
            "signerType": signer.signerType.rawValue
        ])

        try await initializeSigner(signer)

        options?.experimentalCallbacks?.onWalletCreationStart()

        let pendingDeviceSigner = await prepareDeviceSignerEntry(storage: deviceSignerStorage)
        let adminSigner = await signer.adminSigner
        do {
            let creation = try await createWalletRetryingOnceWithoutDeviceSigner(
                chainType: chainType,
                walletType: walletType,
                adminSigner: adminSigner,
                pendingDeviceSigner: pendingDeviceSigner
            )

            if let pendingDeviceSigner, !creation.deviceSignerRejected {
                await mapPendingKey(
                    pendingDeviceSigner.publicKeyBase64,
                    to: creation.model.address,
                    storage: pendingDeviceSigner.storage
                )
            }

            let createSigners = creation.model.config.signers?.compactMap(\.locator) ?? []
            let delegatedSignerLocators = createSigners.isEmpty ? "none" : createSigners.joined(separator: ", ")
            Logger.smartWallet.debug(LogEvents.walletCreateSuccess, attributes: [
                "chainType": chainType.rawValue,
                "address": creation.model.address,
                "delegatedSigners": delegatedSignerLocators
            ])

            return creation
        } catch {
            await pendingDeviceSigner?.discard()
            Logger.smartWallet.error(LogEvents.walletCreateError, attributes: [
                "chainType": chainType.rawValue,
                "error": "\(error)"
            ])
            throw error
        }
    }

    private func prepareDeviceSignerEntry(
        storage: (any DeviceSignerKeyStorage)?
    ) async -> PendingDeviceSigner? {
        guard let storage else {
            Logger.smartWallet.debug(LogEvents.walletCreateDeviceSignerSkipped)
            return nil
        }
        do {
            let publicKeyBase64 = try await storage.generateKey(address: nil)
            let entry = try makeDelegatedSignerEntry(publicKeyBase64: publicKeyBase64)
            Logger.smartWallet.debug(LogEvents.walletCreateDeviceSignerPrepared, attributes: [
                "publicKeyBase64Prefix": String(publicKeyBase64.prefix(16))
            ])
            return PendingDeviceSigner(entry: entry, publicKeyBase64: publicKeyBase64, storage: storage)
        } catch {
            // The device signer is best-effort at creation; the wallet is created without one.
            Logger.smartWallet.warning(LogEvents.walletAddDelegatedSignerError, attributes: [
                "error": "\(error)"
            ])
            return nil
        }
    }

    private func createWalletRetryingOnceWithoutDeviceSigner(
        chainType: ChainType,
        walletType: WalletType,
        adminSigner: any AdminSignerData,
        pendingDeviceSigner: PendingDeviceSigner?
    ) async throws(WalletError) -> (model: WalletApiModel, deviceSignerRejected: Bool) {
        do {
            let model = try await requestWalletCreation(
                chainType: chainType,
                walletType: walletType,
                adminSigner: adminSigner,
                delegatedSigners: pendingDeviceSigner.map { [$0.entry] }
            )
            return (model, deviceSignerRejected: false)
        } catch WalletError.deviceSignerNotSupported where pendingDeviceSigner != nil {
            await pendingDeviceSigner?.discard()
            Logger.smartWallet.info(LogEvents.walletCreateDeviceSignerUnsupportedRetry, attributes: [
                "chainType": chainType.rawValue
            ])
            let model = try await requestWalletCreation(
                chainType: chainType,
                walletType: walletType,
                adminSigner: adminSigner,
                delegatedSigners: nil
            )
            return (model, deviceSignerRejected: true)
        }
    }

    private func mapPendingKey(
        _ publicKeyBase64: String,
        to address: String,
        storage: any DeviceSignerKeyStorage
    ) async {
        do {
            try await storage.mapAddressToKey(address: address, publicKeyBase64: publicKeyBase64)
        } catch {
            try? await storage.deletePendingKey(publicKeyBase64: publicKeyBase64)
            Logger.smartWallet.warning(LogEvents.walletAddDelegatedSignerError, attributes: [
                "error": "\(error)"
            ])
        }
    }

    private func requestWalletCreation(
        chainType: ChainType,
        walletType: WalletType,
        adminSigner: any AdminSignerData,
        delegatedSigners: [DelegatedSignerEntry]?
    ) async throws(WalletError) -> WalletApiModel {
        try await smartWalletService.createWallet(
            CreateWalletParams(
                chainType: chainType,
                type: walletType,
                config: .init(adminSigner: adminSigner, delegatedSigners: delegatedSigners)
            )
        )
    }

    private func buildWallet(
        from walletApiModel: WalletApiModel,
        chain: Chain,
        signer: any Signer,
        options: WalletOptions?,
        deviceSignerStorage: (any DeviceSignerKeyStorage)?,
        deviceSignerUnsupported: Bool = false
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
                deviceSignerKeyStorage: deviceSignerStorage,
                deviceSignerUnsupported: deviceSignerUnsupported
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
                deviceSignerKeyStorage: deviceSignerStorage,
                deviceSignerUnsupported: deviceSignerUnsupported
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
                deviceSignerKeyStorage: deviceSignerStorage,
                deviceSignerUnsupported: deviceSignerUnsupported
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
        guard let deviceSignerPendingAssignment = findMatchingDeviceSignerKey(
            in: walletApiModel,
            storage: storage
        ) else { return }

        do {
            try await storage.mapAddressToKey(
                address: walletApiModel.address,
                publicKeyBase64: deviceSignerPendingAssignment
            )
            Logger.smartWallet.info(LogEvents.walletAddDelegatedSignerSuccess, attributes: [
                "address": walletApiModel.address
            ])
        } catch {
            Logger.smartWallet.warning(LogEvents.walletAddDelegatedSignerError, attributes: [
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

    private func deviceSignerStorage(for options: WalletOptions?) -> (any DeviceSignerKeyStorage)? {
        guard options?.deviceSigner == true else { return nil }
        return deviceSignerKeyStorage
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
}
