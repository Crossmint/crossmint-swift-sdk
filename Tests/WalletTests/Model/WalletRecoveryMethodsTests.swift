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

private let EMAIL = "email:user@example.com"
private let PHONE = "phone:+14155552671"

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

    @Suite("on EVM")
    struct EVMTests {
        private func makeEVMWallet(fileName: String, chain: EVMChain) throws -> EVMWallet {
            let baseModel: WalletApiModel = try GetFromFile.getModelFrom(fileName: fileName, bundle: Bundle.module)
            return try EVMWallet(
                smartWalletService: MockSmartWalletService(),
                signer: MockSigner(),
                baseModel: baseModel,
                evmChain: chain
            )
        }

        @Test(arguments: [
            (EVMChain.baseSepolia, [EMAIL, PHONE], [SignerStatus.active, .awaitingApproval]),
            (EVMChain.polygonAmoy, [EMAIL, PHONE], [.active, .active]),
            (EVMChain.polygon, [EMAIL], [.active])
        ])
        func showsTheRecoveryMethodsOfTheWalletChain(
            chain: EVMChain,
            locators: [String],
            statuses: [SignerStatus]
        ) throws {
            let wallet = try makeEVMWallet(fileName: "WalletEVMRecoveryMethods", chain: chain)

            #expect(wallet.recoveryMethods.map(\.signer.locator) == locators)
            #expect(wallet.recoveryMethods.map(\.status) == statuses)
        }

        @Test func fallsBackToTheAdminSignerWhenNoRecoveryMethodIsOnTheWalletChain() throws {
            let wallet = try makeEVMWallet(fileName: "WalletEVMRecoveryMethodsOnOtherChain", chain: .baseSepolia)

            #expect(wallet.recoveryMethods.map(\.signer.locator) == [EMAIL])
        }
    }
}
