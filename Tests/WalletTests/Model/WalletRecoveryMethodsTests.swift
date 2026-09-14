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

    @Test func findsTheFirstRecoverySignerOfAType() throws {
        let (wallet, _) = try makeSolanaWallet(fileName: "WalletSolanaRecoveryMethods")

        #expect(wallet.config.recoverySigner(ofType: PhoneSignerData.self)?.phone == "+14155552671")
        #expect(wallet.config.recoverySigner(ofType: ApiKeySignerData.self) == nil)
    }

    @Test func selectsARecoverySignerThatIsNotTheFirstOne() async throws {
        let (wallet, _) = try makeSolanaWallet(fileName: "WalletSolanaRecoveryMethods")

        try await wallet.useSigner(.phone("+14155552671"))

        #expect(wallet.selectedSignerLocator == .phone("+14155552671"))
        #expect(wallet.selectedSigner is PhoneSigner)
    }

    @Test func rejectsASignerOutsideTheRecoveryList() async throws {
        let (wallet, _) = try makeSolanaWallet(fileName: "WalletSolanaRecoveryMethods")

        await #expect { try await wallet.useSigner(.email("bob@example.com")) } throws: { error in
            guard case .signerNotRegistered(let locator) = error as? WalletError else { return false }
            return locator == "email:bob@example.com"
        }
    }
}
