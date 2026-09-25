//
//  WalletRecoveryMethodsTests.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 09/09/26.
//

import CrossmintCommonTypes
import CrossmintService
import Foundation
import Testing
import TestsUtils

@testable import Wallet

@Suite("Wallet recovery methods", .tags(.unit))
struct WalletRecoveryMethodsTests {
    private func makeSolanaWallet(
        fileName: String,
        signer: MockSigner = MockSigner(email: "alice@example.com")
    ) throws -> (SolanaWallet, MockSmartWalletService) {
        let baseModel: WalletApiModel = try GetFromFile.getModelFrom(fileName: fileName, bundle: Bundle.module)
        let walletService = MockSmartWalletService()
        walletService.getWalletResult = baseModel
        let wallet = try SolanaWallet(
            smartWalletService: walletService,
            signer: signer,
            baseModel: baseModel,
            solanaChain: .solana
        )
        return (wallet, walletService)
    }

    @Test func findsTheFirstRecoverySignerOfAType() throws {
        let (wallet, _) = try makeSolanaWallet(fileName: "WalletSolanaRecoveryMethods")

        #expect(wallet.config.recoverySigner(ofType: PhoneSignerData.self)?.phone == "+14155552671")
        #expect(wallet.config.recoverySigner(ofType: ApiKeySignerData.self) == nil)
    }

    @Test func selectsARecoverySignerThatIsNotTheFirstOne() async throws {
        let (wallet, _) = try makeSolanaWallet(fileName: "WalletSolanaRecoveryMethods")

        try await wallet.useSigner(.phone("+14155552671"))

        #expect(await wallet.selectedSigner?.locator == .phone("+14155552671"))
        #expect(wallet.selectedSigner is PhoneSigner)
    }

    @Test func rejectsASignerOutsideTheRecoveryList() async throws {
        let (wallet, _) = try makeSolanaWallet(fileName: "WalletSolanaRecoveryMethods")

        await #expect { try await wallet.useSigner(.email("bob@example.com")) } throws: { error in
            guard case .signerNotRegistered(let locator) = error as? WalletError else { return false }
            return locator == "email:bob@example.com"
        }
    }

    @Suite("transaction signer")
    struct TransactionSignerTests {
        private let parent = WalletRecoveryMethodsTests()

        @Test func namesTheActiveRecoverySignerWhenTheWalletHasSeveral() async throws {
            let (wallet, _) = try parent.makeSolanaWallet(fileName: "WalletSolanaRecoveryMethods")

            #expect(try await wallet.transactionSignerLocator() == "email:alice@example.com")
        }

        @Test func omitsTheSignerWhenTheWalletHasASingleRecoverySigner() async throws {
            let (wallet, _) = try parent.makeSolanaWallet(fileName: "WalletSolanaEmail")

            #expect(try await wallet.transactionSignerLocator() == nil)
        }

        @Test func prefersTheSelectedSigner() async throws {
            let (wallet, _) = try parent.makeSolanaWallet(fileName: "WalletSolanaRecoveryMethods")

            try await wallet.useSigner(.phone("+14155552671"))

            #expect(try await wallet.transactionSignerLocator() == "phone:+14155552671")
        }
    }

    @Suite("installation state")
    struct InstallationStateTests {
        private let parent = WalletRecoveryMethodsTests()

        private func decodeFixture(
            _ fileName: String,
            replacing target: String,
            with replacement: String
        ) throws -> WalletConfig {
            let url = try #require(Bundle.module.url(forResource: fileName, withExtension: "json"))
            let fixture = try String(contentsOf: url, encoding: .utf8)
            let json = fixture.replacingOccurrences(of: target, with: replacement)
            return try DefaultJSONCoder().decode(WalletApiModel.self, from: Data(json.utf8)).config.toDomain
        }

        @Test func reportsTheStateOfEachRecoveryMethod() throws {
            let (wallet, _) = try parent.makeSolanaWallet(fileName: "WalletSolanaRecoveryMethods")

            #expect(wallet.recoveryMethodStatuses == [
                "email:alice@example.com": .active,
                "phone:+14155552671": .pending,
                "external-wallet:GbA2NZfpAnRVM2G2BG29qooqsYbdV5c2WVFymJ8MMir7": .failed
            ])
        }

        @Test func reportsAnUnrecognizedStateAsUnknown() throws {
            let config = try decodeFixture("WalletSolanaRecoveryMethods", replacing: "\"failed\"", with: "\"paused\"")

            let locator = "external-wallet:GbA2NZfpAnRVM2G2BG29qooqsYbdV5c2WVFymJ8MMir7"
            #expect(config.recoveryMethodStatuses[locator] == .unknown)
        }

        @Test func reportsNoStateWhenTheApiOmitsIt() throws {
            let evmRecoveryList = """
                "recoveryMethods": [
                  {"type": "email", "email": "user@example.com", "locator": "email:user@example.com"}
                ],
                "adminSigner"
                """
            let config = try decodeFixture("WalletEVMEmail", replacing: "\"adminSigner\"", with: evmRecoveryList)

            #expect(config.recoveryMethods.map(\.locator) == ["email:user@example.com"])
            #expect(config.recoveryMethodStatuses.isEmpty)
        }
    }
}
