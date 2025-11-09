import CrossmintCommonTypes
import CrossmintService
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
    }

    public func getOrCreateWallet(
        chain: Chain,
        signer: any Signer,
        options: WalletOptions? = nil
    ) async throws(WalletError) -> Wallet {
        guard isValid(chain: chain) else {
            let errorMessage = "The chain \(chain.name) is not supported for the current environment"
            throw WalletError.walletCreationFailed(errorMessage)
        }

        let walletApiModel: WalletApiModel
        do {
            walletApiModel = try await smartWalletService.getWallet(GetMeWalletRequest(chainType: chain.chainType))
        } catch WalletError.walletNotFound {
            walletApiModel = try await createWallet(
                signer: signer,
                chainType: chain.chainType,
                walletType: .smart,
                options: options
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
                onTransactionStart: options?.experimentalCallbacks.onTransactionStart
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
                onTransactionStart: options?.experimentalCallbacks.onTransactionStart
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

    private func getEffectiveSigner(
        or signer: any Signer
    ) async throws(SignerError) -> any Signer {
        switch signer.signerType {
        case .externalWallet:
            await getStoredKeyPairSigner() ?? signer
        case .passkey, .apiKey, .email:
            signer
        }
    }

    private func updateEffectiveSigner(_ signer: any Signer) async {
        guard let evmKeyPairSigner = signer as? EVMKeyPairSigner else { return }
        await storeEVMKeyPairSigner(evmKeyPairSigner)
    }

    private func getStoredKeyPairSigner() async -> EVMKeyPairSigner? {
        if let email = await smartWalletService.email,
           let storedPrivateKey = secureWalletStorage.getPrivateKey(forEmail: email),
           let evmKeyPairSigner = try? EVMKeyPairSigner(privateKey: storedPrivateKey) {
            Logger.smartWallet.info("Using stored private key for email: \(email)")
            return evmKeyPairSigner
        }
        return nil
    }

    private func storeEVMKeyPairSigner(_ evmKeyPairSigner: EVMKeyPairSigner) async {
        if let email = await smartWalletService.email {
            await secureWalletStorage.savePrivateKey(evmKeyPairSigner.privateKey, forEmail: email)
        } else {
            Logger.smartWallet.error("Email not found, unable to save private key")
        }
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

    private func createWallet(
        signer: any Signer,
        chainType: ChainType,
        walletType: WalletType,
        options: WalletOptions?
    ) async throws(WalletError) -> WalletApiModel {
        guard let effectiveSigner: any Signer = try? await getEffectiveSigner(or: signer) else {
            throw .walletGeneric("Invalid signer")
        }

        try await initializeSigner(effectiveSigner)

        options?.experimentalCallbacks.onWalletCreationStart()
        let walletApiModel = try await smartWalletService.createWallet(
            CreateWalletParams(
                chainType: chainType,
                type: walletType,
                config: .init(adminSigner: await effectiveSigner.adminSigner)
            )
        )

        await updateEffectiveSigner(effectiveSigner)
        return walletApiModel
    }
}
