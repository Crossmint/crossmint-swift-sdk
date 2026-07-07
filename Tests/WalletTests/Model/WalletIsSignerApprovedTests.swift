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

@Suite("Wallet isSignerApproved", .tags(.unit))
struct WalletIsSignerApprovedTests {

    @Test func approvesActiveChainEntry() async throws {
        let walletService = MockSmartWalletService()
        walletService.getSignerResult = AddDelegatedSignerResponse(
            chains: ["polygon": ChainRegistrationEntry(id: nil, status: "active", approvals: nil)],
            transaction: nil
        )
        let wallet = try makeEVMWallet(walletService: walletService)

        #expect(await wallet.isSignerApproved("email:user@example.com"))
        #expect(walletService.lastGetSignerLocator == "email:user@example.com")
    }

    @Test func approvesSuccessChainEntry() async throws {
        let walletService = MockSmartWalletService()
        walletService.getSignerResult = AddDelegatedSignerResponse(
            chains: ["polygon": ChainRegistrationEntry(id: nil, status: "success", approvals: nil)],
            transaction: nil
        )
        let wallet = try makeEVMWallet(walletService: walletService)

        #expect(await wallet.isSignerApproved("email:user@example.com"))
    }

    @Test func rejectsSignerAwaitingApproval() async throws {
        let walletService = MockSmartWalletService()
        walletService.getSignerResult = AddDelegatedSignerResponse(
            chains: ["polygon": ChainRegistrationEntry(id: "sig-1", status: "awaiting-approval", approvals: nil)],
            transaction: nil
        )
        let wallet = try makeEVMWallet(walletService: walletService)

        #expect(await wallet.isSignerApproved("email:user@example.com") == false)
    }

    @Test func rejectsSignerWithoutEntryForTheWalletChain() async throws {
        let walletService = MockSmartWalletService()
        walletService.getSignerResult = AddDelegatedSignerResponse(
            chains: ["base": ChainRegistrationEntry(id: nil, status: "active", approvals: nil)],
            transaction: nil
        )
        let wallet = try makeEVMWallet(walletService: walletService)

        #expect(await wallet.isSignerApproved("email:user@example.com") == false)
    }

    @Test func approvesSignerCreatedWithTheWallet() async throws {
        let walletService = MockSmartWalletService()
        walletService.getSignerResult = AddDelegatedSignerResponse(chains: nil, transaction: nil)
        let wallet = try makeEVMWallet(walletService: walletService)

        #expect(await wallet.isSignerApproved("email:user@example.com"))
    }

    @Test func rejectsSignerWithPendingTransactionOnSolana() async throws {
        let walletService = MockSmartWalletService()
        walletService.getSignerResult = AddDelegatedSignerResponse(
            chains: nil,
            transaction: RegistrationTransaction(id: "tx-1", status: "pending")
        )
        let wallet = try makeSolanaWallet(walletService: walletService)

        #expect(await wallet.isSignerApproved("email:user@example.com") == false)
    }

    @Test func approvesSignerWithSuccessfulTransactionOnSolana() async throws {
        let walletService = MockSmartWalletService()
        walletService.getSignerResult = AddDelegatedSignerResponse(
            chains: nil,
            transaction: RegistrationTransaction(id: "tx-1", status: "success")
        )
        let wallet = try makeSolanaWallet(walletService: walletService)

        #expect(await wallet.isSignerApproved("email:user@example.com"))
    }

    @Test func approvesSignerWithoutTransactionOnSolana() async throws {
        let walletService = MockSmartWalletService()
        walletService.getSignerResult = AddDelegatedSignerResponse(chains: nil, transaction: nil)
        let wallet = try makeSolanaWallet(walletService: walletService)

        #expect(await wallet.isSignerApproved("email:user@example.com"))
    }

    @Test func returnsFalseOnNetworkError() async throws {
        let walletService = MockSmartWalletService()
        walletService.getSignerError = .walletGeneric("network error")
        let wallet = try makeEVMWallet(walletService: walletService)

        #expect(await wallet.isSignerApproved("email:user@example.com") == false)
    }
}
