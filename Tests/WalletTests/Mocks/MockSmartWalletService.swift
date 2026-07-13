import CrossmintCommonTypes
import CrossmintService
import Foundation
@testable import Wallet

final class MockSmartWalletService: SmartWalletService, @unchecked Sendable {
    var isProductionEnvironment: Bool { false }

    // MARK: - getWallet

    var getWalletResult: WalletApiModel?
    var getWalletError: WalletError?
    var getWalletCallCount = 0

    func getWallet(_ request: GetMeWalletRequest) async throws(WalletError) -> WalletApiModel {
        getWalletCallCount += 1
        if let getWalletError {
            throw getWalletError
        }
        guard let getWalletResult else {
            throw WalletError.walletGeneric("not implemented")
        }
        return getWalletResult
    }

    // MARK: - getSigner

    // getSigner is called concurrently from signers()' task group, so its
    // tracking state is guarded by a lock. (NSLock.withLock needs iOS 16; min target is 15.)
    private let getSignerLock = NSLock()
    private var _getSignerResults: [String: WalletSigner] = [:]
    private var _getSignerErrorLocators: Set<String> = []
    private var _getSignerLocators: [String] = []

    var getSignerResults: [String: WalletSigner] {
        get { withGetSignerLock { _getSignerResults } }
        set { withGetSignerLock { _getSignerResults = newValue } }
    }

    /// Locators for which getSigner throws instead of returning a result.
    var getSignerErrorLocators: Set<String> {
        get { withGetSignerLock { _getSignerErrorLocators } }
        set { withGetSignerLock { _getSignerErrorLocators = newValue } }
    }

    var getSignerLocators: [String] {
        withGetSignerLock { _getSignerLocators }
    }

    func getSigner(
        _ signerLocator: String,
        chainType: ChainType,
        chainName: String
    ) async throws(WalletError) -> WalletSigner? {
        let outcome: Result<WalletSigner?, WalletError> = withGetSignerLock {
            _getSignerLocators.append(signerLocator)
            if _getSignerErrorLocators.contains(signerLocator) {
                return .failure(WalletError.walletGeneric("getSigner failed"))
            }
            return .success(_getSignerResults[signerLocator])
        }
        return try outcome.get()
    }

    private func withGetSignerLock<T>(_ body: () -> T) -> T {
        getSignerLock.lock()
        defer { getSignerLock.unlock() }
        return body()
    }

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

    var registerTypedSignerResult: AddDelegatedSignerResponse = AddDelegatedSignerResponse(chains: nil, transaction: nil)

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

    // MARK: - Unused stubs

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
