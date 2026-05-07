import CrossmintAuth
import CrossmintCommonTypes
import CrossmintService

public final class DefaultSmartWalletService: SmartWalletService {
    private let wallet: DefaultWalletService
    private let transaction: DefaultTransactionService
    private let transfer: DefaultTransferService
    private let balance: DefaultBalanceService
    private let nft: DefaultNFTService
    private let signature: DefaultSignatureService

    public var isProductionEnvironment: Bool { wallet.isProductionEnvironment }

    public var authHeaders: [String: String] {
        get async { await wallet.authHeaders }
    }

    public init(
        crossmintService: CrossmintService,
        authManager: AuthManager,
        jsonCoder: JSONCoder = DefaultJSONCoder()
    ) {
        wallet = DefaultWalletService(
            crossmintService: crossmintService,
            jsonCoder: jsonCoder,
            authManager: authManager
        )
        transaction = DefaultTransactionService(
            crossmintService: crossmintService,
            jsonCoder: jsonCoder,
            authManager: authManager
        )
        transfer = DefaultTransferService(
            crossmintService: crossmintService,
            jsonCoder: jsonCoder,
            authManager: authManager
        )
        balance = DefaultBalanceService(
            crossmintService: crossmintService,
            authManager: authManager
        )
        nft = DefaultNFTService(
            crossmintService: crossmintService,
            authManager: authManager
        )
        signature = DefaultSignatureService(
            crossmintService: crossmintService,
            jsonCoder: jsonCoder,
            authManager: authManager
        )
    }

    // MARK: - WalletService

    public func getWallet(_ request: GetMeWalletRequest) async throws(WalletError) -> WalletApiModel {
        try await wallet.getWallet(request)
    }

    public func createWallet(_ request: CreateWalletParams) async throws(WalletError) -> WalletApiModel {
        try await wallet.createWallet(request)
    }

    public func fund(_ request: FundWalletRequest) async throws(WalletError) {
        try await wallet.fund(request)
    }

    public func addSigner(
        _ entry: DelegatedSignerEntry,
        chainType: ChainType,
        chainName: String
    ) async throws(WalletError) -> AddDelegatedSignerResponse {
        try await wallet.addSigner(entry, chainType: chainType, chainName: chainName)
    }

    public func registerTypedSigner(
        _ signer: any AdminSignerData,
        chainType: ChainType,
        chainName: String
    ) async throws(WalletError) -> AddDelegatedSignerResponse {
        try await wallet.registerTypedSigner(signer, chainType: chainType, chainName: chainName)
    }

    public func removeSigner(
        _ signerLocator: String,
        chainType: ChainType,
        chainName: String
    ) async throws(TransactionError) -> any TransactionApiModel {
        try await wallet.removeSigner(signerLocator, chainType: chainType, chainName: chainName)
    }

    // MARK: - TransactionService

    public func createTransaction(
        _ request: CreateTransactionRequest
    ) async throws(TransactionError) -> any TransactionApiModel {
        try await transaction.createTransaction(request)
    }

    public func signTransaction(
        _ request: SignRequest
    ) async throws(TransactionError) -> any TransactionApiModel {
        try await transaction.signTransaction(request)
    }

    public func fetchTransaction(
        _ request: FetchTransactionRequest
    ) async throws(TransactionError) -> any TransactionApiModel {
        try await transaction.fetchTransaction(request)
    }

    // MARK: - TransferService

    public func transferToken(
        _ request: TransferTokenRequest
    ) async throws(TransactionError) -> any TransactionApiModel {
        try await transfer.transferToken(request)
    }

    public func listTransfers(
        _ params: ListTransfersQueryParams
    ) async throws(WalletError) -> TransferListResult {
        try await transfer.listTransfers(params)
    }

    // MARK: - BalanceService

    public func getBalance(
        _ params: GetBalanceQueryParams
    ) async throws(WalletError) -> Balances {
        try await balance.getBalance(params)
    }

    // MARK: - NFTService

    public func getNFTs(
        _ params: GetNTFQueryParams
    ) async throws(WalletError) -> [NFT] {
        try await nft.getNFTs(params)
    }

    // MARK: - SignatureService

    public func createSignature(
        _ request: CreateSignatureRequest
    ) async throws(SignatureError) -> any SignatureApiModel {
        try await signature.createSignature(request)
    }

    public func approveSignature(_ request: SignRequest) async throws(SignatureError) {
        try await signature.approveSignature(request)
    }

    public func fetchSignature(
        _ signatureId: String,
        chainType: ChainType
    ) async throws(SignatureError) -> any SignatureApiModel {
        try await signature.fetchSignature(signatureId, chainType: chainType)
    }
}
