import CrossmintAuth
import CrossmintCommonTypes
import CrossmintService

public final class DefaultSmartWalletService: SmartWalletService {
    private let walletService: DefaultWalletService
    private let transactionService: DefaultTransactionService
    private let transferService: DefaultTransferService
    private let balanceService: DefaultBalanceService
    private let nftService: DefaultNFTService
    private let signatureService: DefaultSignatureService

    public var isProductionEnvironment: Bool { walletService.isProductionEnvironment }

    public init(
        crossmintService: CrossmintService,
        authManager: AuthManager,
        jsonCoder: JSONCoder = DefaultJSONCoder()
    ) {
        let authenticatedService = AuthenticatedCrossmintService(
            base: crossmintService,
            authManager: authManager
        )
        walletService = DefaultWalletService(
            crossmintService: authenticatedService,
            jsonCoder: jsonCoder
        )
        transactionService = DefaultTransactionService(
            crossmintService: authenticatedService,
            jsonCoder: jsonCoder
        )
        transferService = DefaultTransferService(
            crossmintService: authenticatedService,
            jsonCoder: jsonCoder
        )
        balanceService = DefaultBalanceService(crossmintService: authenticatedService)
        nftService = DefaultNFTService(crossmintService: authenticatedService)
        signatureService = DefaultSignatureService(
            crossmintService: authenticatedService,
            jsonCoder: jsonCoder
        )
    }

    // MARK: - WalletService

    public func getWallet(_ request: GetMeWalletRequest) async throws(WalletError) -> WalletApiModel {
        try await walletService.getWallet(request)
    }

    public func createWallet(_ request: CreateWalletParams) async throws(WalletError) -> WalletApiModel {
        try await walletService.createWallet(request)
    }

    public func fund(_ request: FundWalletRequest) async throws(WalletError) {
        try await walletService.fund(request)
    }

    public func addSigner(
        _ entry: DelegatedSignerEntry,
        chainType: ChainType,
        chainName: String,
        deployImmediately: Bool?
    ) async throws(WalletError) -> AddDelegatedSignerResponse {
        try await walletService.addSigner(
            entry,
            chainType: chainType,
            chainName: chainName,
            deployImmediately: deployImmediately
        )
    }

    public func registerTypedSigner(
        _ signer: any AdminSignerData,
        chainType: ChainType,
        chainName: String,
        deployImmediately: Bool?
    ) async throws(WalletError) -> AddDelegatedSignerResponse {
        try await walletService.registerTypedSigner(
            signer,
            chainType: chainType,
            chainName: chainName,
            deployImmediately: deployImmediately
        )
    }

    public func removeSigner(
        _ signerLocator: String,
        chainType: ChainType,
        chainName: String
    ) async throws(TransactionError) -> any TransactionApiModel {
        try await walletService.removeSigner(signerLocator, chainType: chainType, chainName: chainName)
    }

    // MARK: - TransactionService

    public func createTransaction(
        _ request: CreateTransactionRequest
    ) async throws(TransactionError) -> any TransactionApiModel {
        try await transactionService.createTransaction(request)
    }

    public func signTransaction(
        _ request: SignRequest
    ) async throws(TransactionError) -> any TransactionApiModel {
        try await transactionService.signTransaction(request)
    }

    public func fetchTransaction(
        _ request: FetchTransactionRequest
    ) async throws(TransactionError) -> any TransactionApiModel {
        try await transactionService.fetchTransaction(request)
    }

    // MARK: - TransferService

    public func transferToken(
        _ request: TransferTokenRequest
    ) async throws(TransactionError) -> any TransactionApiModel {
        try await transferService.transferToken(request)
    }

    public func listTransfers(
        _ params: ListTransfersQueryParams
    ) async throws(WalletError) -> TransferListResult {
        try await transferService.listTransfers(params)
    }

    // MARK: - BalanceService

    public func getBalance(
        _ params: GetBalanceQueryParams
    ) async throws(WalletError) -> Balances {
        try await balanceService.getBalance(params)
    }

    // MARK: - NFTService

    public func getNFTs(
        _ params: GetNTFQueryParams
    ) async throws(WalletError) -> [NFT] {
        try await nftService.getNFTs(params)
    }

    // MARK: - SignatureService

    public func createSignature(
        _ request: CreateSignatureRequest
    ) async throws(SignatureError) -> any SignatureApiModel {
        try await signatureService.createSignature(request)
    }

    public func approveSignature(_ request: SignRequest) async throws(SignatureError) {
        try await signatureService.approveSignature(request)
    }

    public func fetchSignature(
        _ signatureId: String,
        chainType: ChainType
    ) async throws(SignatureError) -> any SignatureApiModel {
        try await signatureService.fetchSignature(signatureId, chainType: chainType)
    }
}
