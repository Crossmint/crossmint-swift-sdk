import CrossmintCommonTypes
import Foundation
import SecureStorage
import Testing
@testable import Wallet

private func makeTestWalletApiModel(address: String = "0x1234567890123456789012345678901234567890") -> WalletApiModel {
    let json = """
    {
        "type": "smart",
        "chainType": "evm",
        "config": {
            "adminSigner": {
                "type": "email",
                "email": "test@example.com",
                "locator": "email:test@example.com"
            }
        },
        "address": "\(address)",
        "linkedUser": "email:test@example.com",
        "createdAt": "2025-01-01T00:00:00.000Z"
    }
    """
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    // swiftlint:disable:next force_try
    return try! decoder.decode(WalletApiModel.self, from: Data(json.utf8))
}

@Suite("DefaultCrossmintWallets.getOrCreate", .tags(.unit))
@MainActor struct GetOrCreateTests {

    @Test("Returns existing wallet when getWallet succeeds")
    func returnsExistingWalletWhenFound() async throws {
        let service = GetOrCreateMockWalletService()
        service.getWalletResult = makeTestWalletApiModel(address: "0x1111111111111111111111111111111111111111")
        let wallets = DefaultCrossmintWallets(
            service: service,
            secureWalletStorage: GetOrCreateMockSecureStorage()
        )

        let signer = WalletSigner.email("test@example.com") { _ in }
        let wallet = try await wallets.getOrCreate(
            chain: Chain("base-sepolia"),
            signer: signer
        )

        #expect(wallet.address == "0x1111111111111111111111111111111111111111")
        #expect(service.getWalletCallCount == 1)
        #expect(service.createWalletCallCount == 0)
    }

    @Test("Creates wallet when getWallet returns nil")
    func createsWalletWhenNotFound() async throws {
        let service = GetOrCreateMockWalletService()
        service.getWalletResult = nil
        service.createWalletResult = makeTestWalletApiModel(address: "0x2222222222222222222222222222222222222222")
        let wallets = DefaultCrossmintWallets(
            service: service,
            secureWalletStorage: GetOrCreateMockSecureStorage()
        )

        let signer = WalletSigner.email("test@example.com") { _ in }
        let wallet = try await wallets.getOrCreate(
            chain: Chain("base-sepolia"),
            signer: signer
        )

        #expect(wallet.address == "0x2222222222222222222222222222222222222222")
        #expect(service.getWalletCallCount == 1)
        #expect(service.createWalletCallCount == 1)
    }

    @Test("Propagates error from getWallet")
    func propagatesGetWalletError() async throws {
        let service = GetOrCreateMockWalletService()
        service.getWalletShouldThrow = true
        let wallets = DefaultCrossmintWallets(
            service: service,
            secureWalletStorage: GetOrCreateMockSecureStorage()
        )

        let signer = WalletSigner.email("test@example.com") { _ in }

        await #expect(throws: WalletError.self) {
            _ = try await wallets.getOrCreate(
                chain: Chain("base-sepolia"),
                signer: signer
            )
        }
    }
}

// MARK: - Test doubles

private final class GetOrCreateMockWalletService: SmartWalletService, @unchecked Sendable {
    var authHeaders: [String: String] { [:] }
    var isProductionEnvironment: Bool { false }

    var getWalletResult: WalletApiModel?
    var getWalletCallCount = 0
    var getWalletShouldThrow = false

    var createWalletResult: WalletApiModel?
    var createWalletCallCount = 0

    func getWallet(_ request: GetMeWalletRequest) async throws(WalletError) -> WalletApiModel {
        getWalletCallCount += 1
        if getWalletShouldThrow {
            throw WalletError.walletGeneric("get wallet error")
        }
        guard let result = getWalletResult else {
            throw WalletError.walletNotFound
        }
        return result
    }

    func createWallet(_ request: CreateWalletParams) async throws(WalletError) -> WalletApiModel {
        createWalletCallCount += 1
        guard let result = createWalletResult else {
            throw WalletError.walletGeneric("create wallet result not configured")
        }
        return result
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

    // swiftlint:disable:next function_parameter_count
    func transferToken(
        chainType: String,
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

    func approveSignature(_ request: SignRequest) async throws(SignatureError) {}

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

    func addSigner(
        _ entry: DelegatedSignerEntry,
        chainType: ChainType,
        chainName: String
    ) async throws(WalletError) -> AddDelegatedSignerResponse {
        AddDelegatedSignerResponse(chains: nil)
    }

    func registerTypedSigner(
        _ signer: any AdminSignerData,
        chainType: ChainType,
        chainName: String
    ) async throws(WalletError) -> AddDelegatedSignerResponse {
        AddDelegatedSignerResponse(chains: nil)
    }
}

private struct GetOrCreateMockSecureStorage: SecureWalletStorage {
    func savePrivateKey(_ privateKey: String, forEmail email: String) {}
    func getPrivateKey(forEmail email: String) -> String? { nil }
}
