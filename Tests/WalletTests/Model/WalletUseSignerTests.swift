//
//  WalletUseSignerTests.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 26/08/26.
//

import CrossmintCommonTypes
import Foundation
import Testing
import TestsUtils

@testable import Wallet

@Suite("Wallet useSigner", .tags(.unit))
struct WalletUseSignerTests {
    private func makePhoneWallet() throws -> (EVMWallet, MockSmartWalletService) {
        let baseModel: WalletApiModel = try GetFromFile.getModelFrom(
            fileName: "WalletEVMPhone",
            bundle: Bundle.module
        )
        let walletService = MockSmartWalletService()
        walletService.getWalletResult = baseModel
        let wallet = try EVMWallet(
            smartWalletService: walletService,
            signer: MockSigner(),
            baseModel: baseModel,
            evmChain: .polygon
        )
        return (wallet, walletService)
    }

    @Test func selectsThePhoneRecoverySigner() async throws {
        let (wallet, _) = try makePhoneWallet()

        try await wallet.useSigner(.phone("+14155552671", channel: .whatsapp))

        #expect(wallet.selectedSignerLocator == .phone("+14155552671"))
        let selected = try #require(wallet.selectedSigner as? PhoneSigner)
        #expect(selected.channel == .whatsapp)
    }

    @Test func selectsThePhoneSignerWithoutAChannel() async throws {
        let (wallet, _) = try makePhoneWallet()

        try await wallet.useSigner(.phone("+14155552671"))

        let selected = try #require(wallet.selectedSigner as? PhoneSigner)
        #expect(selected.channel == nil)
    }

    @Test func rejectsAPhoneNumberThatIsNotRegisteredOnTheWallet() async throws {
        let (wallet, _) = try makePhoneWallet()

        await #expect { try await wallet.useSigner(.phone("+15550000000")) } throws: { error in
            guard case .signerNotRegistered(let locator) = error as? WalletError else { return false }
            return locator == "phone:+15550000000"
        }
        #expect(wallet.selectedSignerLocator == nil)
    }

    @Test func buildsAPhoneLocatorThatIgnoresTheChannel() {
        #expect(SignerConfig.phone("+14155552671", channel: .whatsapp).locator == .phone("+14155552671"))
        #expect(SignerConfig.phone("+14155552671").locator == .phone("+14155552671"))
    }
}
