import CrossmintCommonTypes
import CrossmintService
import Foundation
@testable import Wallet

final class MockSmartWalletService: SmartWalletService, @unchecked Sendable {
    var isProductionEnvironment: Bool { false }

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

    var createWalletFixture: Data?
    var createWalletErrors: [WalletError] = []
    var createWalletCallCount = 0
    var allCreateWalletParams: [CreateWalletParams] = []
    var lastCreateWalletParams: CreateWalletParams? { allCreateWalletParams.last }

    func createWallet(_ request: CreateWalletParams) async throws(WalletError) -> WalletApiModel {
        createWalletCallCount += 1
        allCreateWalletParams.append(request)
        if !createWalletErrors.isEmpty {
            throw createWalletErrors.removeFirst()
        }
        guard let createWalletFixture else {
            throw WalletError.walletGeneric("not implemented")
        }
        do {
            return try Self.walletModel(from: createWalletFixture, echoing: request.config.delegatedSigners)
        } catch {
            throw WalletError.walletGeneric("Failed to decode createWallet fixture: \(error)")
        }
    }

    /// Echoes the request's delegated signers into the returned wallet's config,
    /// mirroring what the backend reports for a create-with-signers request.
    private static func walletModel(
        from fixture: Data,
        echoing delegatedSigners: [DelegatedSignerEntry]?
    ) throws -> WalletApiModel {
        var json = try JSONSerialization.jsonObject(with: fixture) as? [String: Any] ?? [:]
        if let delegatedSigners {
            var config = json["config"] as? [String: Any] ?? [:]
            config["delegatedSigners"] = delegatedSigners.map { ["locator": $0.signer, "signer": $0.signer] }
            json["config"] = config
        }
        let patched = try JSONSerialization.data(withJSONObject: json)
        return try DefaultJSONCoder().decode(WalletApiModel.self, from: patched)
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

    // MARK: - removeSigner

    var removeSignerResult: (any TransactionApiModel)?
    var removeSignerError: TransactionError?
    var removeSignerCallCount = 0
    var removeSignerLastLocator: String?

    func removeSigner(
        _ signerLocator: String,
        chainType: ChainType,
        chainName: String
    ) async throws(TransactionError) -> any TransactionApiModel {
        removeSignerCallCount += 1
        removeSignerLastLocator = signerLocator
        if let removeSignerError {
            throw removeSignerError
        }
        guard let removeSignerResult else {
            throw TransactionError.transactionGeneric("not implemented")
        }
        return removeSignerResult
    }

    // MARK: - getWallet

    var getWalletResult: WalletApiModel?

    func getWallet(_ request: GetMeWalletRequest) async throws(WalletError) -> WalletApiModel {
        guard let getWalletResult else {
            throw WalletError.walletGeneric("not implemented")
        }
        return getWalletResult
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

    func listTransfers(_ params: ListTransfersQueryParams) async throws(WalletError) -> TransferListResult {
        throw WalletError.walletGeneric("not implemented")
    }
}
