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

    var getSignerResults: [String: WalletSigner] = [:]
    /// Locators for which getSigner throws instead of returning a result.
    var getSignerErrorLocators: Set<String> = []
    /// Locators for which getSigner suspends briefly before answering,
    /// so tests can invert the completion order of concurrent lookups.
    var getSignerDelayedLocators: Set<String> = []

    // getSigner runs concurrently from signers()' task group. Only the recorded-locators
    // array is mutated during that phase, so a lock guards just it; results and error
    // locators are set during test setup and only read while concurrent.
    // (NSLock.withLock needs iOS 16; min target is 15.)
    private let getSignerLock = NSLock()
    private var _getSignerLocators: [String] = []

    var getSignerLocators: [String] {
        getSignerLock.lock()
        defer { getSignerLock.unlock() }
        return _getSignerLocators
    }

    func getSigner(
        _ signerLocator: String,
        chainType: ChainType,
        chainName: String
    ) async throws(WalletError) -> WalletSigner? {
        recordGetSignerCall(signerLocator)
        if getSignerDelayedLocators.contains(signerLocator) {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        if getSignerErrorLocators.contains(signerLocator) {
            throw WalletError.walletGeneric("getSigner failed")
        }
        return getSignerResults[signerLocator]
    }

    private func recordGetSignerCall(_ locator: String) {
        getSignerLock.lock()
        defer { getSignerLock.unlock() }
        _getSignerLocators.append(locator)
    }

    // MARK: - addSigner

    var addSignerResult: AddDelegatedSignerResponse = AddDelegatedSignerResponse(chains: nil, transaction: nil)
    var addSignerError: WalletError?
    var addSignerCallCount = 0
    var lastAddSignerEntry: DelegatedSignerEntry?
    var lastAddSignerDeployImmediately: Bool?

    func addSigner(
        _ entry: DelegatedSignerEntry,
        chainType: ChainType,
        chainName: String,
        deployImmediately: Bool?
    ) async throws(WalletError) -> AddDelegatedSignerResponse {
        addSignerCallCount += 1
        lastAddSignerEntry = entry
        lastAddSignerDeployImmediately = deployImmediately
        if let addSignerError {
            throw addSignerError
        }
        return addSignerResult
    }

    // MARK: - registerTypedSigner

    var registerTypedSignerResult = AddDelegatedSignerResponse(chains: nil, transaction: nil)
    var registerTypedSignerCallCount = 0
    var lastRegisterTypedSignerDeployImmediately: Bool?

    func registerTypedSigner(
        _ signer: any AdminSignerData,
        chainType: ChainType,
        chainName: String,
        deployImmediately: Bool?
    ) async throws(WalletError) -> AddDelegatedSignerResponse {
        registerTypedSignerCallCount += 1
        lastRegisterTypedSignerDeployImmediately = deployImmediately
        return registerTypedSignerResult
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

    // MARK: - getSigner (registration state)

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
