import CrossmintCommonTypes
import Foundation
import Testing
import TestsUtils

@testable import Wallet

private func makeWallet(walletService: MockSmartWalletService) throws -> EVMWallet {
    let baseModel: WalletApiModel = try GetFromFile.getModelFrom(
        fileName: "WalletEVMApiKeyWithDelegatedSigners",
        bundle: Bundle.module
    )
    walletService.getWalletResult = baseModel
    return try EVMWallet(
        smartWalletService: walletService,
        signer: MockSigner(),
        baseModel: baseModel,
        evmChain: .polygon
    )
}

@Suite("Wallet signerIsRegistered", .tags(.unit))
struct WalletSignerIsRegisteredTests {

    @Test func matchesDelegatedEmailSigner() async throws {
        let wallet = try makeWallet(walletService: MockSmartWalletService())

        #expect(await wallet.signerIsRegistered(.email("user@example.com")))
    }

    @Test func matchesRecoveryApiKeySigner() async throws {
        let wallet = try makeWallet(walletService: MockSmartWalletService())

        #expect(await wallet.signerIsRegistered(.apiKey(address: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb")))
    }

    @Test func matchesApiKeySignerStoredInFallbackSpelling() async throws {
        let wallet = try makeWallet(walletService: MockSmartWalletService())

        #expect(await wallet.signerIsRegistered(.apiKey()))
    }

    @Test func returnsFalseForUnregisteredSigner() async throws {
        let wallet = try makeWallet(walletService: MockSmartWalletService())

        #expect(await wallet.signerIsRegistered(.phone("+15551234567")) == false)
    }

    @Test func returnsFalseOnNetworkError() async throws {
        let walletService = MockSmartWalletService()
        let wallet = try makeWallet(walletService: walletService)
        walletService.getWalletResult = nil

        #expect(await wallet.signerIsRegistered(.email("user@example.com")) == false)
    }
}
