import CrossmintCommonTypes
import CrossmintService
import Foundation
@testable import Wallet

struct CorruptedFixtureError: Error, CustomStringConvertible {
    let description: String
}

extension DelegatedSignerEntry.Signer {
    /// The locator string the backend derives for this entry.
    func locatorValue() throws -> String {
        switch self {
        case .locator(let locator): locator.value
        case .device(let publicKey, _): "device:\(try publicKey.uncompressedBase64())"
        }
    }
}

extension DevicePublicKey {
    func uncompressedBase64() throws -> String {
        func bytes(fromHex hex: String) throws -> [UInt8] {
            let clean = hex.hasPrefix("0x") ? String(hex.dropFirst(2)) : hex
            var out: [UInt8] = []
            var index = clean.startIndex
            while index < clean.endIndex {
                guard let next = clean.index(index, offsetBy: 2, limitedBy: clean.endIndex),
                      let byte = UInt8(clean[index..<next], radix: 16) else {
                    throw CorruptedFixtureError(description: "Invalid hex in device public key coordinate: \(hex)")
                }
                out.append(byte)
                index = next
            }
            return out
        }
        return try Data([0x04] + bytes(fromHex: x) + bytes(fromHex: y)).base64EncodedString()
    }
}

final class MockSmartWalletService: SmartWalletService, @unchecked Sendable {
    var isProductionEnvironment: Bool { false }

    // MARK: - getWallet

    var getWalletResult: WalletApiModel?
    var getWalletError: WalletError?
    var getWalletCallCount = 0
    var getWalletFixture: Data?
    var getWalletSignerLocators: [String]?

    func getWallet(_ request: GetMeWalletRequest) async throws(WalletError) -> WalletApiModel {
        getWalletCallCount += 1
        if let getWalletError {
            throw getWalletError
        }
        if let getWalletResult {
            return getWalletResult
        }
        guard let getWalletFixture else {
            throw WalletError.walletGeneric("not implemented")
        }
        do {
            return try Self.walletModel(from: getWalletFixture, signerLocators: getWalletSignerLocators)
        } catch {
            throw WalletError.walletGeneric("Failed to decode getWallet fixture: \(error)")
        }
    }

    // MARK: - getSigner

    // signers() looks up signer states concurrently from a task group, so the
    // tracking and gating state below is lock-guarded.
    private let getSignerLock = NSLock()
    private var _getSignerResult: AddDelegatedSignerResponse? = AddDelegatedSignerResponse(chains: nil, transaction: nil)
    private var _getSignerResponses: [String: AddDelegatedSignerResponse] = [:]
    private var _getSignerError: WalletError?
    private var _getSignerErrorLocators: Set<String> = []
    private var _getSignerCallCount = 0
    private var _getSignerLocators: [String] = []
    private var _getSignerGatedLocator: String?
    private var _getSignerGateContinuation: CheckedContinuation<Void, Never>?
    private var _getSignerUngatedLookupCompleted = false

    /// Fallback response when no per-locator entry exists in ``getSignerResponses``.
    var getSignerResult: AddDelegatedSignerResponse? {
        get { withGetSignerLock { _getSignerResult } }
        set { withGetSignerLock { _getSignerResult = newValue } }
    }

    /// Per-locator responses, taking precedence over ``getSignerResult``.
    var getSignerResponses: [String: AddDelegatedSignerResponse] {
        get { withGetSignerLock { _getSignerResponses } }
        set { withGetSignerLock { _getSignerResponses = newValue } }
    }

    /// When set, getSigner throws for every locator.
    var getSignerError: WalletError? {
        get { withGetSignerLock { _getSignerError } }
        set { withGetSignerLock { _getSignerError = newValue } }
    }

    var lastGetSignerLocator: String? {
        withGetSignerLock { _getSignerLocators.last }
    }

    /// Locators for which getSigner throws instead of returning a response.
    var getSignerErrorLocators: Set<String> {
        get { withGetSignerLock { _getSignerErrorLocators } }
        set { withGetSignerLock { _getSignerErrorLocators = newValue } }
    }

    var getSignerCallCount: Int {
        withGetSignerLock { _getSignerCallCount }
    }

    var getSignerLocators: [String] {
        withGetSignerLock { _getSignerLocators }
    }

    /// When set, this locator's lookup suspends until another locator's lookup has
    /// completed, so completion order is deterministically inverted for ordering tests.
    var getSignerGatedLocator: String? {
        get { withGetSignerLock { _getSignerGatedLocator } }
        set { withGetSignerLock { _getSignerGatedLocator = newValue } }
    }

    func getSigner(
        _ signerLocator: String,
        chainType: ChainType
    ) async throws(WalletError) -> AddDelegatedSignerResponse? {
        let gated: Bool = withGetSignerLock {
            _getSignerCallCount += 1
            _getSignerLocators.append(signerLocator)
            return signerLocator == _getSignerGatedLocator
        }
        if gated {
            await withCheckedContinuation { continuation in
                let resumeNow: Bool = withGetSignerLock {
                    if _getSignerUngatedLookupCompleted { return true }
                    _getSignerGateContinuation = continuation
                    return false
                }
                if resumeNow { continuation.resume() }
            }
        }
        defer {
            if !gated {
                let continuation: CheckedContinuation<Void, Never>? = withGetSignerLock {
                    _getSignerUngatedLookupCompleted = true
                    let pending = _getSignerGateContinuation
                    _getSignerGateContinuation = nil
                    return pending
                }
                continuation?.resume()
            }
        }
        if let getSignerError {
            throw getSignerError
        }
        if getSignerErrorLocators.contains(signerLocator) {
            throw WalletError.walletGeneric("getSigner failed")
        }
        return getSignerResponses[signerLocator] ?? getSignerResult
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
            return try Self.walletModel(
                from: createWalletFixture,
                signerLocators: request.config.delegatedSigners?.map { try $0.signer.locatorValue() }
            )
        } catch {
            throw WalletError.walletGeneric("Failed to decode createWallet fixture: \(error)")
        }
    }

    /// Writes the given signer locators into the fixture wallet's config,
    /// mirroring what the backend reports for a wallet with delegated signers.
    private static func walletModel(
        from fixture: Data,
        signerLocators: [String]?
    ) throws -> WalletApiModel {
        var json = try JSONSerialization.jsonObject(with: fixture) as? [String: Any] ?? [:]
        if let signerLocators {
            var config = json["config"] as? [String: Any] ?? [:]
            config["delegatedSigners"] = signerLocators.map { ["locator": $0, "signer": $0] }
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

    // MARK: - listTransactions

    var listTransactionsResult: [Transaction] = []
    var listTransactionsError: TransactionError?
    var listTransactionsCallCount = 0
    var lastListTransactionsRequest: ListTransactionsRequest?

    func listTransactions(
        _ request: ListTransactionsRequest
    ) async throws(TransactionError) -> [Transaction] {
        listTransactionsCallCount += 1
        lastListTransactionsRequest = request
        if let listTransactionsError {
            throw listTransactionsError
        }
        return listTransactionsResult
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
