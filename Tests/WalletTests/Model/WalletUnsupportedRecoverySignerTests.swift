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
    return try SolanaWallet(
        smartWalletService: MockSmartWalletService(),
        signer: MockSigner(email: EMAIL),
        baseModel: baseModel,
        solanaChain: .solana
    )
}

@Suite("Wallet with an unsupported recovery signer type", .tags(.unit))
struct WalletUnsupportedRecoverySignerTests {
    @Test func keepsTheSupportedRecoveryMethodsInOrder() throws {
        let wallet = try makeSolanaWallet(fileName: "WalletSolanaUnsupportedSigners")

        let locators = wallet.config.recoveryMethods.map(\.locator)

        #expect(locators == ["email:\(EMAIL)", "phone:\(PHONE)"])
    }

    @Test func usesTheFirstSupportedRecoverySignerWhenTheAdminSignerIsUnsupported() throws {
        let wallet = try makeSolanaWallet(fileName: "WalletSolanaUnsupportedSigners")

        #expect(wallet.config.recovery.locator == "email:\(EMAIL)")
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
            return message.contains("totp")
        }
    }

    @Test func rejectsAnAdminSignerWithASupportedTypeAndInvalidData() throws {
        let url = try #require(
            Bundle.module.url(forResource: "WalletSolanaInvalidAdminSigner", withExtension: "json")
        )
        let data = try Data(contentsOf: url)

        #expect {
            try DefaultJSONCoder().decode(WalletApiModel.self, from: data)
        } throws: { error in
            guard case .invalidData(let message) = error as? CrossmintServiceError else { return false }
            return message.contains("adminSigner")
        }
    }
}
