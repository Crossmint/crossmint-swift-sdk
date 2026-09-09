//
//  WalletRecoveryMethodsTests.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 09/09/26.
//

import CrossmintCommonTypes
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

    @Test func exposesEveryRecoverySignerReportedByTheApi() throws {
        let (wallet, _) = try makeSolanaWallet(fileName: "WalletSolanaRecoveryMethods")

        let locators = wallet.recoveryMethods.map(\.locator)

        #expect(locators == [
            "email:alice@example.com",
            "phone:+14155552671",
            "external-wallet:GbA2NZfpAnRVM2G2BG29qooqsYbdV5c2WVFymJ8MMir7"
        ])
    }

    @Test func findsTheFirstRecoverySignerOfAType() throws {
        let (wallet, _) = try makeSolanaWallet(fileName: "WalletSolanaRecoveryMethods")

        #expect(wallet.config.recoverySigner(ofType: PhoneSignerData.self)?.phone == "+14155552671")
        #expect(wallet.config.recoverySigner(ofType: ApiKeySignerData.self) == nil)
    }

    @Test func fallsBackToTheAdminSignerWhenTheApiReportsNoList() throws {
        let (wallet, _) = try makeSolanaWallet(fileName: "WalletSolanaEmail")

        #expect(wallet.recoveryMethods.map(\.locator) == ["email:solana.user@example.com"])
    }

    @Test func selectsARecoverySignerThatIsNotTheFirstOne() async throws {
        let (wallet, _) = try makeSolanaWallet(fileName: "WalletSolanaRecoveryMethods")

        try await wallet.useSigner(.phone("+14155552671"))

        #expect(wallet.selectedSignerLocator == "phone:+14155552671")
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

            #expect(await wallet.transactionSignerLocator() == "email:alice@example.com")
        }

        @Test func omitsTheSignerWhenTheWalletHasASingleRecoverySigner() async throws {
            let (wallet, _) = try parent.makeSolanaWallet(fileName: "WalletSolanaEmail")

            #expect(await wallet.transactionSignerLocator() == nil)
        }

        @Test func prefersTheSelectedSigner() async throws {
            let (wallet, _) = try parent.makeSolanaWallet(fileName: "WalletSolanaRecoveryMethods")

            try await wallet.useSigner(.phone("+14155552671"))

            #expect(await wallet.transactionSignerLocator() == "phone:+14155552671")
        }
    }
}
