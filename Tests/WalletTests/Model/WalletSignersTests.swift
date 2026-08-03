import CrossmintCommonTypes
import Foundation
import Testing
import TestsUtils

@testable import Wallet

private let DEVICE_LOCATOR = "device:8Ht1jWbGgXcDqFv3nRkPzYw5mT2uLsEaK9oC4dNbV6xJ"
private let EMAIL_LOCATOR = "email:delegate@example.com"

private func makeSolanaWallet(
    walletService: MockSmartWalletService,
    fixture: String = "WalletSolanaSigners"
) throws -> SolanaWallet {
    let baseModel: WalletApiModel = try GetFromFile.getModelFrom(
        fileName: fixture,
        bundle: Bundle.module
    )
    walletService.getWalletResult = baseModel
    return try SolanaWallet(
        smartWalletService: walletService,
        signer: MockSigner(),
        baseModel: baseModel,
        solanaChain: .solana,
        onTransactionStart: nil
    )
}

@Suite("Wallet signers", .tags(.unit))
struct WalletSignersTests {

    @Test func returnsEachSignerWithItsStatusInConfigOrder() async throws {
        let walletService = MockSmartWalletService()
        walletService.getSignerResults = [
            DEVICE_LOCATOR: WalletSigner(locator: DEVICE_LOCATOR, status: .active),
            EMAIL_LOCATOR: WalletSigner(locator: EMAIL_LOCATOR, status: .pending)
        ]
        // Delay the first signer so the second completes first — the returned
        // list must still follow the config order, not the completion order.
        walletService.getSignerDelayedLocators = [DEVICE_LOCATOR]
        let wallet = try makeSolanaWallet(walletService: walletService)

        let signers = try await wallet.signers()

        #expect(signers == [
            WalletSigner(locator: DEVICE_LOCATOR, status: .active),
            WalletSigner(locator: EMAIL_LOCATOR, status: .pending)
        ])
    }

    @Test func requestsTheStateOfEveryConfiguredSigner() async throws {
        let walletService = MockSmartWalletService()
        let wallet = try makeSolanaWallet(walletService: walletService)

        _ = try await wallet.signers()

        #expect(Set(walletService.getSignerLocators) == [DEVICE_LOCATOR, EMAIL_LOCATOR])
    }

    @Test func returnsUnknownStatusForSignersWhoseStateLookupFails() async throws {
        let walletService = MockSmartWalletService()
        walletService.getSignerResults = [
            EMAIL_LOCATOR: WalletSigner(locator: EMAIL_LOCATOR, status: .active)
        ]
        walletService.getSignerErrorLocators = [DEVICE_LOCATOR]
        let wallet = try makeSolanaWallet(walletService: walletService)

        let signers = try await wallet.signers()

        #expect(signers == [
            WalletSigner(locator: DEVICE_LOCATOR, status: .unknown),
            WalletSigner(locator: EMAIL_LOCATOR, status: .active)
        ])
    }

    @Test func omitsSignersWithoutRegistrationForTheWalletChain() async throws {
        let walletService = MockSmartWalletService()
        walletService.getSignerResults = [
            DEVICE_LOCATOR: WalletSigner(locator: DEVICE_LOCATOR, status: .active)
        ]
        let wallet = try makeSolanaWallet(walletService: walletService)

        let signers = try await wallet.signers()

        #expect(signers == [WalletSigner(locator: DEVICE_LOCATOR, status: .active)])
    }

    @Test func returnsEmptyListForAWalletWithoutSigners() async throws {
        let walletService = MockSmartWalletService()
        let wallet = try makeSolanaWallet(walletService: walletService, fixture: "WalletSolanaEmail")

        let signers = try await wallet.signers()

        #expect(signers.isEmpty)
        #expect(walletService.getSignerLocators.isEmpty)
    }

    @Test func rethrowsTheErrorWhenTheWalletFetchFails() async throws {
        let walletService = MockSmartWalletService()
        let wallet = try makeSolanaWallet(walletService: walletService)
        walletService.getWalletError = .walletGeneric("wallet fetch exploded")

        await #expect(throws: WalletError.self) {
            try await wallet.signers()
        }
    }
}
