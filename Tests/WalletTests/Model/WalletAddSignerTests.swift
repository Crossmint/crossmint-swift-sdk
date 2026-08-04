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
}
