import CrossmintCommonTypes
import Foundation
import Testing
@testable import Wallet

@Suite("Heartbeat: wallets API contract", .serialized, Tier.heartbeat)
struct WalletsHeartbeatTests {
    static let EVM_CHAIN_NAME = "base-sepolia"
    static let MESSAGE = "heartbeat"

    private struct EVM {
        let session: CryptoWalletSession
        let wallet: Wallet
        let service: DefaultSmartWalletService
        var approver: SignerLocator { .externalWallet(address: session.address) }
        var adminLocator: String { session.signer.adminSigner.locator }
    }

    private func evm() async throws -> EVM {
        let session = try await SessionPool.shared.primary()
        let wallet = try await SessionPool.shared.evmWallet(of: session)
        return EVM(session: session, wallet: wallet, service: session.smartWalletService())
    }

    private func signMessage(_ evm: EVM) -> CreateSignatureRequest {
        CreateSignatureRequest(
            signMessageRequest: SignMessageRequest(
                params: .init(
                    message: Self.MESSAGE,
                    chain: IntegrationEnvironment.EVM_CHAIN,
                    signer: evm.session.signer.adminSigner
                )
            ),
            chainType: .evm
        )
    }

    private func locator(_ wallet: Wallet) throws -> WalletLocator {
        .address(try Address(address: wallet.address))
    }

    private func zeroValueCall(_ wallet: Wallet, signer: String) throws -> CreateTransactionRequest {
        CreateTransactionRequest(
            request: CreateEVMTransactionRequest(
                contractAddress: try EVMAddress(address: wallet.address),
                value: "0",
                data: "0x",
                chain: try #require(EVMChain(Self.EVM_CHAIN_NAME)),
                signer: signer
            ),
            chainType: .evm
        )
    }

    @Test func getWallet() async throws {
        let evm = try await evm()
        let model = try await evm.service.getWallet(GetMeWalletRequest(chainType: .evm))
        #expect(model.address == evm.wallet.address)
        #expect(model.chainType == .evm)
        #expect(model.config.adminSigner.type == .externalWallet)
    }

    @Test func createWallet() async throws {
        let evm = try await evm()
        let created = try await evm.session.wallets().createWallet(
            chain: IntegrationEnvironment.EVM_CHAIN, recovery: evm.session.signer, options: nil
        )
        #expect(created.address == evm.wallet.address)
    }

    @Test func fund() async throws {
        let evm = try await evm()
        try await evm.service.fund(FundWalletRequest(
            token: "usdxm", amount: 1, chain: Self.EVM_CHAIN_NAME, address: try Address(address: evm.wallet.address)
        ))
    }

    @Test func getBalance() async throws {
        let evm = try await evm()
        try await Funding.fund(evm.wallet, usdxm: 1)
        let balances = try await evm.service.getBalance(GetBalanceQueryParams(
            walletLocator: try locator(evm.wallet), tokens: [.usdxm], chains: [IntegrationEnvironment.EVM_CHAIN]
        ))
        #expect(balances.tokens.contains(.usdxm))
    }

    @Test func createTransaction() async throws {
        let evm = try await evm()
        let call = try zeroValueCall(evm.wallet, signer: evm.adminLocator)
        let transaction = try await evm.service.createTransaction(call)
            .toDomain()
        #expect(!transaction.id.isEmpty)
        #expect(transaction.status == .awaitingApproval)
        #expect(transaction.approvals?.pending.isEmpty == false)
    }

    @Test func signTransaction() async throws {
        let evm = try await evm()
        let created = try await evm.service.createTransaction(try zeroValueCall(evm.wallet, signer: evm.adminLocator))
            .toDomain()
        let message = try #require(created.approvals?.pending.first?.message)
        let request = try await evm.wallet.makeSignRequest(for: evm.adminLocator, message: message)
        let sign = SignRequest(transactionId: created.id, apiRequest: request, chainType: .evm)
        let signed = try await evm.service.signTransaction(sign)
            .toDomain()
        #expect(signed.id == created.id)
        #expect(signed.status != TransactionStatus.awaitingApproval)
    }

    @Test func fetchTransaction() async throws {
        let evm = try await evm()
        let created = try await evm.service.createTransaction(try zeroValueCall(evm.wallet, signer: evm.adminLocator))
            .toDomain()
        let fetch = FetchTransactionRequest(transactionId: created.id, chainType: .evm)
        let fetched = try await evm.service.fetchTransaction(fetch)
            .toDomain()
        #expect(fetched.id == created.id)
    }

    @Test func listTransactions() async throws {
        let evm = try await evm()
        let call = try zeroValueCall(evm.wallet, signer: evm.adminLocator)
        let created = try await evm.service.createTransaction(call).toDomain()
        let list = ListTransactionsRequest(chainType: .evm, page: 1, perPage: 5)
        let transactions = try await evm.service.listTransactions(list)
        #expect(transactions.contains { $0.id == created.id })
    }

    @Test func transferToken() async throws {
        let evm = try await evm()
        let recipient = try await SessionPool.shared.secondary()
        try await Funding.fund(evm.wallet, usdxm: 1)
        let transfer = try await evm.service.transferToken(TransferTokenRequest(
            chainType: .evm,
            tokenLocator: IntegrationEnvironment.EVM_USDXM,
            recipient: recipient.address,
            amount: "0.01",
            signer: nil,
            idempotencyKey: nil
        )).toDomain()
        #expect(!transfer.id.isEmpty)
    }

    @Test func listTransfers() async throws {
        let evm = try await evm()
        _ = try await evm.service.listTransfers(ListTransfersQueryParams(
            walletLocator: try locator(evm.wallet), chain: IntegrationEnvironment.EVM_CHAIN, tokens: [.usdxm]
        ))
    }

    @Test func getNFTs() async throws {
        let evm = try await evm()
        _ = try await evm.service.getNFTs(GetNTFQueryParams(
            walletLocator: try locator(evm.wallet), chain: IntegrationEnvironment.EVM_CHAIN, page: 1, perPage: 1
        ))
    }

    @Test func createSignature() async throws {
        let evm = try await evm()
        let signature = try await evm.service.createSignature(signMessage(evm))
        #expect(!signature.id.isEmpty)
        #expect(signature.status == "awaiting-approval")
        #expect(!signature.approvals.pending.isEmpty)
    }

    @Test func approveSignature() async throws {
        let evm = try await evm()
        let signature = try await evm.service.createSignature(signMessage(evm))
        let message = try #require(signature.approvals.pending.first?.message)
        let request = try await evm.wallet.makeSignRequest(for: evm.adminLocator, message: message)
        let sign = SignRequest(transactionId: signature.id, apiRequest: request, chainType: .evm)
        try await evm.service.approveSignature(sign)
    }

    @Test func fetchSignature() async throws {
        let evm = try await evm()
        let signature = try await evm.service.createSignature(signMessage(evm))
        let fetched = try await evm.service.fetchSignature(signature.id, chainType: .evm)
        #expect(fetched.id == signature.id)
    }

    @Test func addSigner() async throws {
        let evm = try await evm()
        let delegate = try await EVMPersonalSigner.make()
        let registration = try await evm.service.addSigner(
            DelegatedSignerEntry(signer: .locator(.externalWallet(address: delegate.address))),
            chainType: .evm,
            chainName: Self.EVM_CHAIN_NAME,
            deployImmediately: true,
            approver: evm.approver
        )
        let entry = try #require(registration.chains?[Self.EVM_CHAIN_NAME])
        #expect(entry.id != nil)
    }

    @Test func getSigner() async throws {
        let evm = try await evm()
        let delegate = try await EVMPersonalSigner.make()
        _ = try await evm.service.addSigner(
            DelegatedSignerEntry(signer: .locator(.externalWallet(address: delegate.address))),
            chainType: .evm,
            chainName: Self.EVM_CHAIN_NAME,
            deployImmediately: true,
            approver: evm.approver
        )
        _ = try #require(try await evm.service.getSigner(delegate.adminSigner.locator, chainType: .evm))
    }

    @Test func removeSigner() async throws {
        let evm = try await evm()
        let delegate = try await EVMPersonalSigner.make()
        try await evm.wallet.addSigner(delegate.config)
        let registered = try await Eventually.value(describing: "\(delegate.address) becoming active") {
            try await evm.wallet.signers().first { signer in
                signer.locator.value.lowercased() == delegate.adminSigner.locator.lowercased()
                    && signer.status == .active
            }
        }
        let removal = try await evm.service.removeSigner(
            registered.locator.value,
            chainType: .evm,
            chainName: Self.EVM_CHAIN_NAME,
            approver: evm.approver
        ).toDomain()
        #expect(!removal.id.isEmpty)
    }

    @Test func addRecoveryMethod() async throws {
        let session = try await SessionPool.shared.primary()
        let (_, recovery) = try await SessionPool.shared.solanaWallet(of: session)
        let added = try await session.smartWalletService().addRecoveryMethod(
            SolanaKeypairSigner().adminSigner,
            chainType: .solana,
            approver: .externalWallet(address: recovery.address)
        ).toDomain()
        #expect(!added.id.isEmpty)
    }

    @Test func removeRecoveryMethod() async throws {
        let session = try await SessionPool.shared.primary()
        let (wallet, recovery) = try await SessionPool.shared.solanaWallet(of: session)
        let second = SolanaKeypairSigner()
        _ = try await wallet.addRecoveryMethod(second.config)
        let removal = try await session.smartWalletService().removeRecoveryMethod(
            .externalWallet(address: second.address),
            chainType: .solana,
            approver: .externalWallet(address: recovery.address)
        ).toDomain()
        #expect(!removal.id.isEmpty)
    }
}
