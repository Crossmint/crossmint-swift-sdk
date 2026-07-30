import CrossmintCommonTypes
@testable import Wallet

final class MockSmartWalletService: SmartWalletService, @unchecked Sendable {
    var isProductionEnvironment: Bool { false }

    // MARK: - addSigner

    var addSignerResult: AddDelegatedSignerResponse = AddDelegatedSignerResponse(chains: nil, transaction: nil)
    var addSignerError: WalletError?
    var addSignerCallCount = 0
    var lastAddSignerEntry: DelegatedSignerEntry?

    func addSigner(
        _ entry: DelegatedSignerEntry,
        chainType: ChainType,
        chainName: String
    ) async throws(WalletError) -> AddDelegatedSignerResponse {
        addSignerCallCount += 1
        lastAddSignerEntry = entry
        if let addSignerError {
            throw addSignerError
        }
        return addSignerResult
    }

    // MARK: - registerTypedSigner

    var registerTypedSignerResult = AddDelegatedSignerResponse(chains: nil, transaction: nil)

    func registerTypedSigner(
        _ signer: any AdminSignerData,
        chainType: ChainType,
        chainName: String
    ) async throws(WalletError) -> AddDelegatedSignerResponse {
        registerTypedSignerResult
    }

    // MARK: - approveSignature

    var approveSignatureCallCount = 0
    var lastApproveSignatureRequest: SignRequest?

    func approveSignature(_ request: SignRequest) async throws(SignatureError) {
        approveSignatureCallCount += 1
        lastApproveSignatureRequest = request
    }

    // MARK: - createWallet

    var createWalletResult: WalletApiModel?
    var lastCreateWalletParams: CreateWalletParams?

    func createWallet(_ request: CreateWalletParams) async throws(WalletError) -> WalletApiModel {
        lastCreateWalletParams = request
        guard let createWalletResult else {
            throw WalletError.walletGeneric("not implemented")
        }
        return createWalletResult
    }

    // MARK: - fetchTransaction / signTransaction

    var fetchTransactionResult: (any TransactionApiModel)?
    var lastFetchTransactionRequest: FetchTransactionRequest?
    var signTransactionCallCount = 0
    var lastSignTransactionRequest: SignRequest?

    func fetchTransaction(
        _ fetchTransactionRequest: FetchTransactionRequest
    ) async throws(TransactionError) -> any TransactionApiModel {
        lastFetchTransactionRequest = fetchTransactionRequest
        guard let fetchTransactionResult else {
            throw TransactionError.transactionGeneric("not implemented")
        }
        return fetchTransactionResult
    }

    func signTransaction(_ request: SignRequest) async throws(TransactionError) -> any TransactionApiModel {
        signTransactionCallCount += 1
        lastSignTransactionRequest = request
        guard let fetchTransactionResult else {
            throw TransactionError.transactionGeneric("not implemented")
        }
        return fetchTransactionResult
    }

    // MARK: - getSigner

    var getSignerResult: AddDelegatedSignerResponse? = AddDelegatedSignerResponse(chains: nil, transaction: nil)
    var getSignerError: WalletError?
    var getSignerCallCount = 0
    var lastGetSignerLocator: String?

    func getSigner(
        _ signerLocator: String,
        chainType: ChainType
    ) async throws(WalletError) -> AddDelegatedSignerResponse? {
        getSignerCallCount += 1
        lastGetSignerLocator = signerLocator
        if let getSignerError {
            throw getSignerError
        }
        return getSignerResult
    }

    // MARK: - Unused stubs

    func getWallet(_ request: GetMeWalletRequest) async throws(WalletError) -> WalletApiModel {
        throw WalletError.walletGeneric("not implemented")
    }

    func getBalance(_ params: GetBalanceQueryParams) async throws(WalletError) -> Balances {
        throw WalletError.walletGeneric("not implemented")
    }

    func getNFTs(_ params: GetNTFQueryParams) async throws(WalletError) -> [NFT] {
        throw WalletError.walletGeneric("not implemented")
    }

    func createTransaction(
        _ request: CreateTransactionRequest
    ) async throws(TransactionError) -> any TransactionApiModel {
        throw TransactionError.transactionGeneric("not implemented")
    }

    func fund(_ request: FundWalletRequest) async throws(WalletError) {}

    func transferToken(
        _ request: TransferTokenRequest
    ) async throws(TransactionError) -> any TransactionApiModel {
        throw TransactionError.transactionGeneric("not implemented")
    }

    func createSignature(
        _ request: CreateSignatureRequest
    ) async throws(SignatureError) -> any SignatureApiModel {
        throw SignatureError.unknown
    }

    func fetchSignature(
        _ signatureId: String,
        chainType: ChainType
    ) async throws(SignatureError) -> any SignatureApiModel {
        throw SignatureError.unknown
    }

    var removeSignerCallCount = 0
    var lastRemoveSignerLocator: String?

    func removeSigner(
        _ signerLocator: String,
        chainType: ChainType,
        chainName: String
    ) async throws(TransactionError) -> any TransactionApiModel {
        removeSignerCallCount += 1
        lastRemoveSignerLocator = signerLocator
        throw TransactionError.transactionGeneric("not implemented")
    }

    func listTransfers(_ params: ListTransfersQueryParams) async throws(WalletError) -> TransferListResult {
        throw WalletError.walletGeneric("not implemented")
    }
}
