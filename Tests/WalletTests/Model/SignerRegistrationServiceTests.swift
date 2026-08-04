import CrossmintCommonTypes
import Foundation
import Testing
import TestsUtils
@testable import Wallet

struct SignerRegistrationServiceTests {
    private let chainType = ChainType.evm
    private let chainName = "polygon"

    private func makeService(walletService: MockSmartWalletService) -> SignerRegistrationService {
        SignerRegistrationService(
            smartWalletService: walletService,
            chainType: chainType,
            chainName: chainName
        )
    }

    // MARK: - register(locator:signer:)

    @Test
    func registerLocator_callsAddSignerWithLocator() async throws {
        let walletService = MockSmartWalletService()
        let signer = MockSigner()
        let service = makeService(walletService: walletService)

        try await service.register(locator: "email:test@example.com", signer: signer)

        #expect(walletService.addSignerCallCount == 1)
        #expect(walletService.lastAddSignerEntry?.signer == "email:test@example.com")
    }

    @Test
    func registerLocator_noApprovalNeeded_doesNotCallApproveSignature() async throws {
        let walletService = MockSmartWalletService()
        walletService.addSignerResult = AddDelegatedSignerResponse(chains: [
            chainName: ChainRegistrationEntry(id: "sig1", status: .active, approvals: nil)
        ], transaction: nil)
        let signer = MockSigner()
        let service = makeService(walletService: walletService)

        try await service.register(locator: "email:test@example.com", signer: signer)

        #expect(walletService.approveSignatureCallCount == 0)
    }

    @Test
    func registerLocator_awaitingApproval_approvesEachPendingEntry() async throws {
        let walletService = MockSmartWalletService()
        walletService.addSignerResult = AddDelegatedSignerResponse(chains: [
            chainName: ChainRegistrationEntry(
                id: "sig1",
                status: .awaitingApproval,
                approvals: RegistrationApprovals(pending: [
                    ApprovalEntry(signer: SignerApiModel(locator: "email:admin@example.com"), message: "0xabc"),
                    ApprovalEntry(signer: SignerApiModel(locator: "email:admin@example.com"), message: "0xdef")
                ])
            )
        ], transaction: nil)
        let signer = MockSigner()
        let service = makeService(walletService: walletService)

        try await service.register(locator: "email:test@example.com", signer: signer)

        #expect(walletService.approveSignatureCallCount == 2)
        #expect(signer.initializeCallCount == 1)
    }

    // MARK: - approveIfNeeded

    @Test
    func approveIfNeeded_nilChains_returnsEarly() async throws {
        let walletService = MockSmartWalletService()
        let signer = MockSigner()
        let service = makeService(walletService: walletService)

        let registration = AddDelegatedSignerResponse(chains: nil, transaction: nil)
        try await service.approveIfNeeded(registration: registration, signer: signer)

        #expect(walletService.approveSignatureCallCount == 0)
    }

    @Test
    func approveIfNeeded_differentChain_returnsEarly() async throws {
        let walletService = MockSmartWalletService()
        let signer = MockSigner()
        let service = makeService(walletService: walletService)

        let registration = AddDelegatedSignerResponse(chains: [
            "ethereum": ChainRegistrationEntry(
                id: "sig1",
                status: .awaitingApproval,
                approvals: RegistrationApprovals(pending: [
                    ApprovalEntry(signer: SignerApiModel(locator: "email:admin@example.com"), message: "0xabc")
                ])
            )
        ], transaction: nil)
        try await service.approveIfNeeded(registration: registration, signer: signer)

        #expect(walletService.approveSignatureCallCount == 0)
    }

    @Test
    func approveIfNeeded_notAwaitingApproval_returnsEarly() async throws {
        let walletService = MockSmartWalletService()
        let signer = MockSigner()
        let service = makeService(walletService: walletService)

        let registration = AddDelegatedSignerResponse(chains: [
            chainName: ChainRegistrationEntry(id: "sig1", status: .active, approvals: nil)
        ], transaction: nil)
        try await service.approveIfNeeded(registration: registration, signer: signer)

        #expect(walletService.approveSignatureCallCount == 0)
    }

    @Test
    func approveIfNeeded_emptyPending_returnsEarly() async throws {
        let walletService = MockSmartWalletService()
        let signer = MockSigner()
        let service = makeService(walletService: walletService)

        let registration = AddDelegatedSignerResponse(chains: [
            chainName: ChainRegistrationEntry(
                id: "sig1",
                status: .awaitingApproval,
                approvals: RegistrationApprovals(pending: [])
            )
        ], transaction: nil)
        try await service.approveIfNeeded(registration: registration, signer: signer)

        #expect(walletService.approveSignatureCallCount == 0)
    }

    @Test
    func approveIfNeeded_sendsCorrectSignatureId() async throws {
        let walletService = MockSmartWalletService()
        let signer = MockSigner()
        let service = makeService(walletService: walletService)

        let registration = AddDelegatedSignerResponse(chains: [
            chainName: ChainRegistrationEntry(
                id: "expected-sig-id",
                status: .awaitingApproval,
                approvals: RegistrationApprovals(pending: [
                    ApprovalEntry(signer: SignerApiModel(locator: "email:admin@example.com"), message: "0xabc")
                ])
            )
        ], transaction: nil)
        try await service.approveIfNeeded(registration: registration, signer: signer)

        #expect(walletService.lastApproveSignatureRequest?.transactionId == "expected-sig-id")
    }

}

@Suite("Signer Registration Transaction Approval", .tags(.unit))
struct SignerRegistrationTransactionApprovalTests {
    private func makeSolanaService(walletService: MockSmartWalletService) -> SignerRegistrationService {
        SignerRegistrationService(
            smartWalletService: walletService,
            chainType: .solana,
            chainName: "solana"
        )
    }

    @Test
    func fetchesAndApprovesPendingApprovalsFromTheRegistrationTransaction() async throws {
        let walletService = MockSmartWalletService()
        let registrationTransaction: SolanaTransactionApiModel = try GetFromFile.getModelFrom(
            fileName: "SolanaSignerRegistrationAwaitingApproval",
            bundle: Bundle.module
        )
        walletService.fetchTransactionResult = registrationTransaction
        let signer = MockSigner()
        let service = makeSolanaService(walletService: walletService)

        let registration = AddDelegatedSignerResponse(
            chains: nil,
            transaction: RegistrationTransaction(id: "registration-tx-1")
        )
        try await service.approveIfNeeded(registration: registration, signer: signer)

        #expect(walletService.lastFetchTransactionRequest?.transactionId == "registration-tx-1")
        #expect(walletService.signTransactionCallCount == 1)
        #expect(walletService.lastSignTransactionRequest?.transactionId == "registration-tx-1")
        #expect(signer.initializeCallCount == 1)
        #expect(walletService.approveSignatureCallCount == 0)
    }

    @Test
    func throwsWalletErrorWhenTheTransactionFetchFails() async throws {
        let walletService = MockSmartWalletService()
        let signer = MockSigner()
        let service = makeSolanaService(walletService: walletService)

        let registration = AddDelegatedSignerResponse(
            chains: nil,
            transaction: RegistrationTransaction(id: "registration-tx-1")
        )

        await #expect(throws: WalletError.self) {
            try await service.approveIfNeeded(registration: registration, signer: signer)
        }
    }

    @Test
    func skipsApprovalWhenRegistrationHasNoChainsAndNoTransaction() async throws {
        let walletService = MockSmartWalletService()
        let signer = MockSigner()
        let service = makeSolanaService(walletService: walletService)

        let registration = AddDelegatedSignerResponse(chains: nil, transaction: nil)
        try await service.approveIfNeeded(registration: registration, signer: signer)

        #expect(walletService.signTransactionCallCount == 0)
        #expect(walletService.approveSignatureCallCount == 0)
    }
}

@Suite("Signer Registration deployImmediately Approval Routing", .tags(.unit))
struct SignerRegistrationDeployImmediatelyApprovalTests {
    private let chainType = ChainType.evm
    private let chainName = "base-sepolia"

    private func makeService(walletService: MockSmartWalletService) -> SignerRegistrationService {
        SignerRegistrationService(
            smartWalletService: walletService,
            chainType: chainType,
            chainName: chainName
        )
    }

    @Test
    func routesToTransactionApprovalWhenChainEntryHasOnChain() async throws {
        let walletService = MockSmartWalletService()
        let awaitingApprovalTransaction: EVMTransactionApiModel = try GetFromFile.getModelFrom(
            fileName: "CreateTransactionAwaitingApproval",
            bundle: Bundle.module
        )
        walletService.fetchTransactionResult = awaitingApprovalTransaction
        let signer = MockSigner()
        let service = makeService(walletService: walletService)

        let registration = AddDelegatedSignerResponse(chains: [
            chainName: ChainRegistrationEntry(
                id: "tx-789",
                status: .awaitingApproval,
                approvals: nil,
                onChain: ChainRegistrationOnChain()
            )
        ], transaction: nil)

        try await service.approveIfNeeded(registration: registration, signer: signer)

        #expect(walletService.lastFetchTransactionRequest?.transactionId == "tx-789")
        #expect(walletService.signTransactionCallCount == 1)
        #expect(walletService.approveSignatureCallCount == 0)
    }

    @Test
    func routesToSignatureApprovalWhenChainEntryHasNoOnChain() async throws {
        let walletService = MockSmartWalletService()
        let signer = MockSigner()
        let service = makeService(walletService: walletService)

        let registration = AddDelegatedSignerResponse(chains: [
            chainName: ChainRegistrationEntry(
                id: "sig-123",
                status: .awaitingApproval,
                approvals: RegistrationApprovals(pending: [
                    ApprovalEntry(signer: SignerApiModel(locator: "email:admin@example.com"), message: "0xabc")
                ])
            )
        ], transaction: nil)

        try await service.approveIfNeeded(registration: registration, signer: signer)

        #expect(walletService.approveSignatureCallCount == 1)
        #expect(walletService.signTransactionCallCount == 0)
        #expect(walletService.lastApproveSignatureRequest?.transactionId == "sig-123")
    }

    @Test
    func routesToSignatureApprovalWhenChainEntryStatusIsPending() async throws {
        let walletService = MockSmartWalletService()
        let signer = MockSigner()
        let service = makeService(walletService: walletService)

        let registration = AddDelegatedSignerResponse(chains: [
            chainName: ChainRegistrationEntry(
                id: "sig-456",
                status: .pending,
                approvals: RegistrationApprovals(pending: [
                    ApprovalEntry(signer: SignerApiModel(locator: "email:admin@example.com"), message: "0xabc")
                ])
            )
        ], transaction: nil)

        try await service.approveIfNeeded(registration: registration, signer: signer)

        #expect(walletService.approveSignatureCallCount == 1)
        #expect(walletService.signTransactionCallCount == 0)
        #expect(walletService.lastApproveSignatureRequest?.transactionId == "sig-456")
    }
}
