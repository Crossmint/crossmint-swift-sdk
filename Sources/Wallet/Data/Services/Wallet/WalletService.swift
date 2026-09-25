import CrossmintCommonTypes

public protocol WalletService: Sendable {
    var isProductionEnvironment: Bool { get }

    func getWallet(
        _ request: GetMeWalletRequest
    ) async throws(WalletError) -> WalletApiModel

    func createWallet(
        _ request: CreateWalletParams
    ) async throws(WalletError) -> WalletApiModel

    func fund(
        _ request: FundWalletRequest
    ) async throws(WalletError)

    func addSigner(
        _ entry: DelegatedSignerEntry,
        chainType: ChainType,
        chainName: String,
        deployImmediately: Bool?
    ) async throws(WalletError) -> AddDelegatedSignerResponse

    func addSigner(
        _ entry: DelegatedSignerEntry,
        chainType: ChainType,
        chainName: String,
        deployImmediately: Bool?,
        approver: SignerLocator?
    ) async throws(WalletError) -> AddDelegatedSignerResponse

    func registerTypedSigner(
        _ signer: any AdminSignerData,
        chainType: ChainType,
        chainName: String,
        deployImmediately: Bool?
    ) async throws(WalletError) -> AddDelegatedSignerResponse

    func registerTypedSigner(
        _ signer: any AdminSignerData,
        chainType: ChainType,
        chainName: String,
        deployImmediately: Bool?,
        approver: SignerLocator?
    ) async throws(WalletError) -> AddDelegatedSignerResponse

    func removeSigner(
        _ signerLocator: String,
        chainType: ChainType,
        chainName: String
    ) async throws(TransactionError) -> any TransactionApiModel

    func removeSigner(
        _ signerLocator: String,
        chainType: ChainType,
        chainName: String,
        approver: SignerLocator?
    ) async throws(TransactionError) -> any TransactionApiModel

    func getSigner(
        _ signerLocator: String,
        chainType: ChainType
    ) async throws(WalletError) -> AddDelegatedSignerResponse?

    func addRecoveryMethod(
        _ recoveryMethod: any AdminSignerData,
        chainType: ChainType,
        approver: SignerLocator
    ) async throws(WalletError) -> any TransactionApiModel

    func removeRecoveryMethod(
        _ locator: SignerLocator,
        chainType: ChainType,
        approver: SignerLocator
    ) async throws(WalletError) -> any TransactionApiModel
}

public extension WalletService {
    func addSigner(
        _ entry: DelegatedSignerEntry,
        chainType: ChainType,
        chainName: String,
        deployImmediately: Bool?,
        approver: SignerLocator?
    ) async throws(WalletError) -> AddDelegatedSignerResponse {
        try await addSigner(
            entry,
            chainType: chainType,
            chainName: chainName,
            deployImmediately: deployImmediately
        )
    }

    func registerTypedSigner(
        _ signer: any AdminSignerData,
        chainType: ChainType,
        chainName: String,
        deployImmediately: Bool?,
        approver: SignerLocator?
    ) async throws(WalletError) -> AddDelegatedSignerResponse {
        try await registerTypedSigner(
            signer,
            chainType: chainType,
            chainName: chainName,
            deployImmediately: deployImmediately
        )
    }

    func removeSigner(
        _ signerLocator: String,
        chainType: ChainType,
        chainName: String,
        approver: SignerLocator?
    ) async throws(TransactionError) -> any TransactionApiModel {
        try await removeSigner(signerLocator, chainType: chainType, chainName: chainName)
    }

    func addRecoveryMethod(
        _ recoveryMethod: any AdminSignerData,
        chainType: ChainType,
        approver: SignerLocator
    ) async throws(WalletError) -> any TransactionApiModel {
        throw .walletGeneric("This WalletService implementation does not implement addRecoveryMethod")
    }

    func removeRecoveryMethod(
        _ locator: SignerLocator,
        chainType: ChainType,
        approver: SignerLocator
    ) async throws(WalletError) -> any TransactionApiModel {
        throw .walletGeneric("This WalletService implementation does not implement removeRecoveryMethod")
    }
}
