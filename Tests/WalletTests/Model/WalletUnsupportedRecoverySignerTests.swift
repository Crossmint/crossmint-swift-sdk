//
//  WalletUnsupportedRecoverySignerTests.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 24/09/26.
//

import CrossmintCommonTypes
import CrossmintService
import Foundation
import Testing
import TestsUtils

@testable import Wallet

private let EMAIL = "alice@example.com"
private let PHONE = "+14155552671"

private func makeSolanaWallet(fileName: String) throws -> SolanaWallet {
    let baseModel: WalletApiModel = try GetFromFile.getModelFrom(fileName: fileName, bundle: Bundle.module)
    let walletService = MockSmartWalletService()
    walletService.getWalletResult = baseModel
    return try SolanaWallet(
        smartWalletService: walletService,
        signer: MockSigner(email: EMAIL),
        baseModel: baseModel,
        solanaChain: .solana
    )
}

@Suite("Wallet with an unsupported recovery signer type", .tags(.unit))
struct WalletUnsupportedRecoverySignerTests {
    @Test func keepsTheSupportedRecoveryMethodsInOrder() throws {
        let wallet = try makeSolanaWallet(fileName: "WalletSolanaUnsupportedRecoveryMethod")

        let locators = wallet.config.recoveryMethods.map(\.locator)

        #expect(locators == ["email:\(EMAIL)", "phone:\(PHONE)"])
    }

    @Test func selectsASupportedRecoverySigner() async throws {
        let wallet = try makeSolanaWallet(fileName: "WalletSolanaUnsupportedRecoveryMethod")

        try await wallet.useSigner(.phone(PHONE))

        #expect(await wallet.selectedSigner?.locator == .phone(PHONE))
    }

    @Test func usesTheFirstSupportedRecoverySignerWhenTheAdminSignerIsUnsupported() throws {
        let wallet = try makeSolanaWallet(fileName: "WalletSolanaUnsupportedAdminSigner")

        #expect(wallet.config.recovery.locator == "email:\(EMAIL)")
        #expect(wallet.config.recoveryMethods.count == 1)
    }

    @Test func rejectsAWalletWithoutASupportedRecoverySigner() throws {
        let url = try #require(
            Bundle.module.url(forResource: "WalletSolanaOnlyUnsupportedSigner", withExtension: "json")
        )
        let data = try Data(contentsOf: url)

        #expect {
            try DefaultJSONCoder().decode(WalletApiModel.self, from: data)
        } throws: { error in
            guard case .invalidData(let message) = error as? CrossmintServiceError else { return false }
            return message == "Unsupported recovery signer type \"totp\""
        }
    }
}
