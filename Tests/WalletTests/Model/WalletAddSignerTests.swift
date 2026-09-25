import CrossmintCommonTypes
import Foundation
import Testing
import TestsUtils

@testable import Wallet

private func makeEVMWallet(walletService: MockSmartWalletService) throws -> EVMWallet {
    let baseModel: WalletApiModel = try GetFromFile.getModelFrom(
        fileName: "WalletEVMEmail",
        bundle: Bundle.module
    )
    return try EVMWallet(
        smartWalletService: walletService,
        signer: MockSigner(),
        baseModel: baseModel,
        evmChain: .polygon
    )
}

private func makeSolanaWallet(walletService: MockSmartWalletService) throws -> SolanaWallet {
    let baseModel: WalletApiModel = try GetFromFile.getModelFrom(
        fileName: "WalletSolanaEmail",
        bundle: Bundle.module
    )
    return try SolanaWallet(
        smartWalletService: walletService,
        signer: MockSigner(),
        baseModel: baseModel,
        solanaChain: .solana
    )
}

private func makeMultiRecoverySolanaWallet(
    walletService: MockSmartWalletService,
    defaultSigner: MockSigner = MockSigner(email: "alice@example.com")
) throws -> SolanaWallet {
    let baseModel: WalletApiModel = try GetFromFile.getModelFrom(
        fileName: "WalletSolanaRecoveryMethods",
        bundle: Bundle.module
    )
    walletService.getWalletResult = baseModel
    return try SolanaWallet(
        smartWalletService: walletService,
        signer: defaultSigner,
        baseModel: baseModel,
        solanaChain: .solana
    )
}

@Suite("Wallet addSigner", .tags(.unit))
struct WalletAddSignerTests {

    @Test func deploysImmediatelyWhenTheFlagIsOmittedOnEVM() async throws {
        let walletService = MockSmartWalletService()
        let wallet = try makeEVMWallet(walletService: walletService)

        try await wallet.addSigner(.email("user@example.com"))

        #expect(walletService.lastAddSignerDeployImmediately == true)
    }

    @Test func deploysImmediatelyOnChainsWithoutTheOverload() async throws {
        let walletService = MockSmartWalletService()
        let wallet = try makeSolanaWallet(walletService: walletService)

        try await wallet.addSigner(.email("user@example.com"))

        #expect(walletService.lastAddSignerDeployImmediately == true)
    }

    @Test func threadsFalseFromTheEVMOverload() async throws {
        let walletService = MockSmartWalletService()
        let wallet = try makeEVMWallet(walletService: walletService)

        try await wallet.addSigner(.email("user@example.com"), deployImmediately: false)

        #expect(walletService.lastAddSignerDeployImmediately == false)
    }

    @Test func threadsTrueFromTheEVMOverload() async throws {
        let walletService = MockSmartWalletService()
        let wallet = try makeEVMWallet(walletService: walletService)

        try await wallet.addSigner(.email("user@example.com"), deployImmediately: true)

        #expect(walletService.lastAddSignerDeployImmediately == true)
    }

    @Suite("approver")
    struct ApproverTests {
        @Test func omitsTheApproverOnAWalletWithOneRecoverySigner() async throws {
            let walletService = MockSmartWalletService()
            let wallet = try makeSolanaWallet(walletService: walletService)

            try await wallet.addSigner(.externalWallet("GbA2NZfpAnRVM2G2BG29qooqsYbdV5c2WVFymJ8MMir7"))

            #expect(walletService.lastAddSignerApprover == nil)
        }

        @Test func namesTheSelectedRecoverySigner() async throws {
            let walletService = MockSmartWalletService()
            let wallet = try makeMultiRecoverySolanaWallet(walletService: walletService)
            try await wallet.useSigner(.phone("+14155552671"))

            try await wallet.addSigner(.externalWallet("GbA2NZfpAnRVM2G2BG29qooqsYbdV5c2WVFymJ8MMir7"))

            #expect(walletService.lastAddSignerApprover == .phone("+14155552671"))
        }

        @Test func namesTheDefaultSignerWhenItIsARecoverySigner() async throws {
            let walletService = MockSmartWalletService()
            let wallet = try makeMultiRecoverySolanaWallet(walletService: walletService)

            try await wallet.addSigner(.externalWallet("GbA2NZfpAnRVM2G2BG29qooqsYbdV5c2WVFymJ8MMir7"))

            #expect(walletService.lastAddSignerApprover == .email("alice@example.com"))
        }

        @Test func refusesADefaultSignerThatIsNotARecoverySigner() async throws {
            let walletService = MockSmartWalletService()
            let wallet = try makeMultiRecoverySolanaWallet(
                walletService: walletService,
                defaultSigner: MockSigner(email: "operator@example.com")
            )

            await #expect {
                try await wallet.addSigner(.externalWallet("GbA2NZfpAnRVM2G2BG29qooqsYbdV5c2WVFymJ8MMir7"))
            } throws: { error in
                guard case .recoveryConfigRejected(let code, _) = error as? WalletError else { return false }
                return code == .signerRequired
            }
            #expect(walletService.addSignerCallCount == 0)
        }

        @Test func namesTheRecoveryMethodSelectedWithUseRecoveryMethodOverTheActiveSigner() async throws {
            let walletService = MockSmartWalletService()
            let wallet = try makeMultiRecoverySolanaWallet(walletService: walletService)
            try await wallet.useSigner(.email("alice@example.com"))
            try await wallet.useRecoveryMethod(.phone("+14155552671"))

            try await wallet.addSigner(.externalWallet("GbA2NZfpAnRVM2G2BG29qooqsYbdV5c2WVFymJ8MMir7"))

            #expect(walletService.lastAddSignerApprover == .phone("+14155552671"))
        }

        @Test func refusesARecoveryMethodTheWalletDoesNotHave() async throws {
            let walletService = MockSmartWalletService()
            let wallet = try makeMultiRecoverySolanaWallet(walletService: walletService)

            await #expect {
                try await wallet.useRecoveryMethod(.email("stranger@example.com"))
            } throws: { error in
                guard case .signerNotRegistered(let locator) = error as? WalletError else { return false }
                return locator == "email:stranger@example.com"
            }
        }

        @Test func refusesASelectedSignerThatIsNotARecoverySigner() async throws {
            let walletService = MockSmartWalletService()
            let storage = MockDeviceSignerKeyStorage()
            let baseModel: WalletApiModel = try GetFromFile.getModelFrom(
                fileName: "WalletSolanaRecoveryMethods",
                bundle: Bundle.module
            )
            walletService.getWalletResult = baseModel
            let wallet = try SolanaWallet(
                smartWalletService: walletService,
                signer: MockSigner(email: "alice@example.com"),
                baseModel: baseModel,
                solanaChain: .solana,
                deviceSignerKeyStorage: storage
            )
            _ = try await storage.generateKey(address: wallet.address)
            try await wallet.useSigner(.device)

            await #expect {
                try await wallet.addSigner(.externalWallet("GbA2NZfpAnRVM2G2BG29qooqsYbdV5c2WVFymJ8MMir7"))
            } throws: { error in
                guard case .recoveryConfigRejected(let code, let message) = error as? WalletError else { return false }
                return code == .signerRequired && message.contains("phone:+14155552671")
            }
            #expect(walletService.addSignerCallCount == 0)
        }

        @Test func namesTheSelectedRecoverySignerWhenRemovingASigner() async throws {
            let walletService = MockSmartWalletService()
            let removed: SolanaTransactionApiModel = try GetFromFile.getModelFrom(
                fileName: "RemoveSignerTransactionSuccess",
                bundle: Bundle.module
            )
            walletService.removeSignerResult = removed
            let wallet = try makeMultiRecoverySolanaWallet(walletService: walletService)
            try await wallet.useSigner(.phone("+14155552671"))

            _ = try await wallet.removeSigner(locator: .device(publicKey: "abc"))

            #expect(walletService.removeSignerLastApprover == .phone("+14155552671"))
        }
    }
}
