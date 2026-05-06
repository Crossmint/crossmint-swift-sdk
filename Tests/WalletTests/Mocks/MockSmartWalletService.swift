import CrossmintCommonTypes
import CrossmintService
@testable import Wallet

final class MockSmartWalletService: SmartWalletService, @unchecked Sendable {
    var authHeaders: [String: String] { [:] }
    var isProductionEnvironment: Bool { false }

    // MARK: - addSigner

    var addSignerResult: AddDelegatedSignerResponse = AddDelegatedSignerResponse(chains: nil)
    var addSignerCallCount = 0
    var lastAddSignerEntry: DelegatedSignerEntry?

    func addSigner(
        _ entry: DelegatedSignerEntry,
        chainType: ChainType,
        chainName: String
    ) async throws(WalletError) -> AddDelegatedSignerResponse {
        addSignerCallCount += 1
        lastAddSignerEntry = entry
        return addSignerResult
    }

    // MARK: - registerTypedSigner

    var registerTypedSignerResult: AddDelegatedSignerResponse = AddDelegatedSignerResponse(chains: nil)

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

    // MARK: - Unused stubs

    func getWallet(_ request: GetMeWalletRequest) async throws(WalletError) -> WalletApiModel {
        throw WalletError.walletGeneric("not implemented")
    }

    func createWallet(_ request: CreateWalletParams) async throws(WalletError) -> WalletApiModel {
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

    func signTransaction(_ request: SignRequest) async throws(TransactionError) -> any TransactionApiModel {
        throw TransactionError.transactionGeneric("not implemented")
    }

    func fetchTransaction(
        _ fetchTransactionRequest: FetchTransactionRequest
    ) async throws(TransactionError) -> any TransactionApiModel {
        throw TransactionError.transactionGeneric("not implemented")
    }

    func fund(_ request: FundWalletRequest) async throws(WalletError) {}

    func transferToken(
        chainType: ChainType,
        tokenLocator: String,
        recipient: String,
        amount: String,
        signer: String?,
        idempotencyKey: String?
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

    func removeSigner(
        _ signerLocator: String,
        chainType: ChainType,
        chainName: String
    ) async throws(TransactionError) -> any TransactionApiModel {
        throw TransactionError.transactionGeneric("not implemented")
    }

    func listTransfers(_ params: ListTransfersQueryParams) async throws(WalletError) -> TransferListResult {
        throw WalletError.walletGeneric("not implemented")
    }
}
