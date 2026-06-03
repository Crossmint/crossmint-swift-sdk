import CrossmintCommonTypes
import DeviceSigner
import Foundation

/// Internal actor that owns all wallet state and orchestrates operations.
///
/// The three concrete wallet types (`EVMWallet`, `SolanaWallet`, `StellarWallet`) each hold an
/// instance of this actor and forward protocol method calls to it. Actor isolation replaces the
/// `@unchecked Sendable` annotation on the old `Wallet` class.
internal actor WalletCore {
    let blockchainAddress: Address
    let chain: Chain
    let config: WalletConfig
    let owner: Owner?

    let smartWalletService: SmartWalletService
    let deviceSignerService: DeviceSignerService
    let signerRegistrationService: SignerRegistrationService

    var signer: any Signer
    var selectedSigner: (any Signer)?
    var selectedSignerLocator: String?
    var deviceSignerKeyStorage: (any DeviceSignerKeyStorage)?
    var needsRecovery: Bool = false
    var deviceSignerApproved: Bool = false
    var initialDelegatedSigners: [WalletDelegatedSignerConfigApiModel] = []
    var signerInitialized: Bool = false

    var onTransactionStart: (@Sendable () -> Void)?

    var address: String { blockchainAddress.description }
    var locator: WalletLocator { .address(blockchainAddress) }

    internal init(
        blockchainAddress: Address,
        chain: Chain,
        baseModel: WalletApiModel,
        signer: any Signer,
        smartWalletService: SmartWalletService,
        deviceSignerService: DeviceSignerService,
        signerRegistrationService: SignerRegistrationService,
        deviceSignerKeyStorage: (any DeviceSignerKeyStorage)? = nil,
        onTransactionStart: (@Sendable () -> Void)? = nil
    ) {
        self.blockchainAddress = blockchainAddress
        self.chain = chain
        self.config = baseModel.config.toDomain
        self.owner = baseModel.owner
        self.signer = signer
        self.smartWalletService = smartWalletService
        self.deviceSignerService = deviceSignerService
        self.signerRegistrationService = signerRegistrationService
        self.deviceSignerKeyStorage = deviceSignerKeyStorage
        self.onTransactionStart = onTransactionStart
        self.initialDelegatedSigners = baseModel.config.signers ?? []
    }
}
