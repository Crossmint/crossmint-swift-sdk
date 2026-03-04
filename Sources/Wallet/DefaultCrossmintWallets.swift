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

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    public func getOrCreateWallet(
        chain: Chain,
        signer: any Signer,
        options: WalletOptions? = nil
    ) async throws(WalletError) -> Wallet {
        guard isValid(chain: chain) else {
            let errorMessage = "The chain \(chain.name) is not supported for the current environment"
            Logger.smartWallet.error(LogEvents.walletFactoryGetOrCreateWalletError, attributes: [
                "error": errorMessage
            ])
            throw WalletError.walletCreationFailed(errorMessage)
        }

        Logger.smartWallet.debug(LogEvents.walletGetOrCreateStart, attributes: [
            "chain": chain.name,
            "signerType": signer.signerType.rawValue
        ])

        let deviceSignerStorage = makeDeviceSignerStorage(options: options)

        let walletApiModel: WalletApiModel
        do {
            walletApiModel = try await smartWalletService.getWallet(GetMeWalletRequest(chainType: chain.chainType))
            let signers = walletApiModel.config.delegatedSigners?.compactMap(\.locator) ?? []
            let existingDelegatedLocators = signers.isEmpty ? "none" : signers.joined(separator: ", ")
            Logger.smartWallet.debug(LogEvents.walletGetOrCreateExisting, attributes: [
                "chain": chain.name,
                "address": walletApiModel.address,
                "delegatedSigners": existingDelegatedLocators
            ])

            // Existing wallet: register device signer if not yet present or not registered on backend
            if let storage = deviceSignerStorage {
                let existingPublicKeyBase64 = await storage.getKey(address: walletApiModel.address)
                let isRegistered = isDeviceSignerRegistered(existingPublicKeyBase64, in: walletApiModel)
                if !isRegistered {
                    Logger.smartWallet.info(LogEvents.walletAddDelegatedSignerStart, attributes: [
                        "address": walletApiModel.address
                    ])
                    do {
                        let publicKeyBase64: String
                        if let existing = existingPublicKeyBase64 {
                            publicKeyBase64 = existing
                        } else {
                            publicKeyBase64 = try await storage.generateKey(address: nil)
                        }
                        let entry = try makeDelegatedSignerEntry(publicKeyBase64: publicKeyBase64)
                        let registration = try await smartWalletService.addDelegatedSigner(
                            entry, chainType: chain.chainType, chainName: chain.name
                        )
                        if let chainEntry = registration.chains?[chain.name],
                           chainEntry.status == "awaiting-approval",
                           let signatureId = chainEntry.id,
                           let pending = chainEntry.approvals?.pending, !pending.isEmpty {
                            try await approveDelegatedSignerRegistration(
                                signatureId: signatureId,
                                pendingApprovals: pending,
                                signer: signer,
                                chainType: chain.chainType
                            )
                        }
                        // Only rename if we generated a new pending key; existing keys are already under wallet tag
                        if existingPublicKeyBase64 == nil {
                            try await storage.mapAddressToKey(
                                address: walletApiModel.address,
                                publicKeyBase64: publicKeyBase64
                            )
                        }
                        Logger.smartWallet.info(LogEvents.walletAddDelegatedSignerSuccess, attributes: [
                            "address": walletApiModel.address
                        ])
                    } catch {
                        Logger.smartWallet.warn(LogEvents.walletAddDelegatedSignerError, attributes: [
                            "error": "\(error)"
                        ])
                        // Device signer registration failed — continue without it
                    }
                }
            }
        } catch WalletError.walletNotFound {
            Logger.smartWallet.debug(LogEvents.walletGetOrCreateCreating, attributes: [
                "chain": chain.name
            ])
            walletApiModel = try await createWallet(
                signer: signer,
                chainType: chain.chainType,
                walletType: .smart,
                options: options,
                deviceSignerStorage: deviceSignerStorage
            )
        }

        let wallet: Wallet
        switch walletApiModel.chainType {
        case .evm:
            guard let evmChain: EVMChain = EVMChain(chain.name) else {
                throw WalletError.walletInvalidType("The wallet received is not compatible with EVM")
            }

            wallet = try EVMWallet(
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

            wallet = try SolanaWallet(
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

            wallet = try StellarWallet(
                smartWalletService: smartWalletService,
                signer: signer,
                baseModel: walletApiModel,
                stellarChain: stellarChain,
                onTransactionStart: options?.experimentalCallbacks?.onTransactionStart,
                deviceSignerKeyStorage: deviceSignerStorage
            )
        case .unknown:
            throw .walletGeneric("Unknown wallet chain")
        }

        do {
            try await (signer as? any EmailSigner)?.load()
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

    private func isValid(chain: AnyChain) -> Bool {
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
    private func createWallet(
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
                    Logger.smartWallet.warn(LogEvents.walletAddDelegatedSignerError, attributes: [
                        "error": "\(error)"
                    ])
                }
            }

            let createSigners = walletApiModel.config.delegatedSigners?.compactMap(\.locator) ?? []
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

    private func makeDeviceSignerStorage(options: WalletOptions?) -> (any DeviceSignerKeyStorage)? {
        guard let deviceSignerOptions = options?.deviceSigner else { return nil }
        if SecureEnclave.isAvailable {
            return SecureEnclaveKeyStorage(biometricPolicy: deviceSignerOptions.biometricPolicy)
        } else {
            return SoftwareDeviceSignerKeyStorage()
        }
    }

    private func isDeviceSignerRegistered(_ publicKeyBase64: String?, in wallet: WalletApiModel) -> Bool {
        guard let keyBase64 = publicKeyBase64,
              let rawKey = Data(base64Encoded: keyBase64), rawKey.count == 64 else {
            return false
        }
        let uncompressed = Data([0x04]) + rawKey
        let locator = "device:\(uncompressed.base64EncodedString())"
        return wallet.config.delegatedSigners?.contains(where: { $0.locator == locator }) ?? false
    }

    private func makeDelegatedSignerEntry(publicKeyBase64: String) throws(WalletError) -> DelegatedSignerEntry {
        guard let rawPublicKey = Data(base64Encoded: publicKeyBase64), rawPublicKey.count == 64 else {
            throw WalletError.walletCreationFailed("Invalid device signer public key")
        }
        // Build uncompressed P256 point: 0x04 || x (32 bytes) || y (32 bytes)
        let uncompressed = Data([0x04]) + rawPublicKey
        return DelegatedSignerEntry(signer: "device:\(uncompressed.base64EncodedString())")
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
