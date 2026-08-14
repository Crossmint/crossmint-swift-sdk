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

    func registerTypedSigner(
        _ signer: any AdminSignerData,
        chainType: ChainType,
        chainName: String,
        deployImmediately: Bool?
    ) async throws(WalletError) -> AddDelegatedSignerResponse

    func removeSigner(
        _ signerLocator: String,
        chainType: ChainType,
        chainName: String
    ) async throws(TransactionError) -> any TransactionApiModel

    func getSigner(
        _ signerLocator: String,
        chainType: ChainType
    ) async throws(WalletError) -> AddDelegatedSignerResponse?
}
