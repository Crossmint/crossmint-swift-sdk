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

            let error = await #expect(throws: WalletError.self) {
                try await wallet.addSigner(.externalWallet("GbA2NZfpAnRVM2G2BG29qooqsYbdV5c2WVFymJ8MMir7"))
            }

            #expect(error?.code == "SIGNER_REQUIRED")
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

        @Test func selectsAnApiKeyRecoveryMethodByItsStoredLocator() async throws {
            let walletService = MockSmartWalletService()
            let baseModel: WalletApiModel = try GetFromFile.getModelFrom(
                fileName: "WalletSolanaFireblocks",
                bundle: Bundle.module
            )
            let wallet = try SolanaWallet(
                smartWalletService: walletService,
                signer: MockSigner(),
                baseModel: baseModel,
                solanaChain: .solana
            )
            try await wallet.useRecoveryMethod(.apiKey)

            try await wallet.addSigner(.externalWallet("GbA2NZfpAnRVM2G2BG29qooqsYbdV5c2WVFymJ8MMir7"))

            let approver = SignerLocator.apiKey(address: "DHQgLgfheQbTMnMc6GrnqGxQ4sL9zAazyWWE9GJ1LUWq")
            #expect(walletService.lastAddSignerApprover == approver)
        }

        @Test(arguments: [
            (nil, "v-Qxh--c2nOkUyBYJHRaXCwSOJw"),
            ("c2Vjb25kLXBhc3NrZXk", "c2Vjb25kLXBhc3NrZXk")
        ] as [(String?, String)])
        func selectsThePasskeyRecoveryMethodOfTheWallet(id: String?, selectedId: String) async throws {
            let walletService = MockSmartWalletService()
            let baseModel: WalletApiModel = try GetFromFile.getModelFrom(
                fileName: "WalletStellarPasskey",
                bundle: Bundle.module
            )
            let wallet = try StellarWallet(
                smartWalletService: walletService,
                signer: MockSigner(email: "alice@example.com"),
                baseModel: baseModel,
                stellarChain: .stellar
            )
            try await wallet.useRecoveryMethod(.passkey(name: "alice", host: "example.com", id: id))

            try await wallet.addSigner(.externalWallet("GDQP2KPQGKIHYJGXNUIYOMHARUARCA7DJT5FO2FFOOKY3B2WSQHG4W37"))

            #expect(walletService.lastAddSignerApprover == .passkey(credentialId: selectedId))
        }

        @Test(arguments: [
            SignerConfig.email("stranger@example.com"),
            SignerConfig.passkey(name: "alice", host: "example.com")
        ])
        func refusesARecoveryMethodTheWalletDoesNotHave(method: SignerConfig) async throws {
            let walletService = MockSmartWalletService()
            let wallet = try makeMultiRecoverySolanaWallet(walletService: walletService)

            let error = await #expect(throws: WalletError.self) {
                try await wallet.useRecoveryMethod(method)
            }

            #expect(error?.code == "INVALID_RECOVERY_CONFIG")
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

            let error = await #expect(throws: WalletError.self) {
                try await wallet.addSigner(.externalWallet("GbA2NZfpAnRVM2G2BG29qooqsYbdV5c2WVFymJ8MMir7"))
            }

            #expect(error?.code == "SIGNER_REQUIRED")
            #expect(error?.message.contains("+14155552671") == false)
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
