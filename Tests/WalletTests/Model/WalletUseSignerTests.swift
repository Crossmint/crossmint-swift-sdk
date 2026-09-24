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

        #expect(await wallet.selectedSigner?.locator == .phone("+14155552671"))
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
        #expect(wallet.selectedSigner == nil)
    }

    @Test func selectsARegisteredDelegatedSigner() async throws {
        let (wallet, walletService) = try makeEVMWallet(fileName: "WalletEVMApiKeyWithDelegatedSigners")

        try await wallet.useSigner(.email("user@example.com"))

        #expect(await wallet.selectedSigner?.locator == .email("user@example.com"))
        #expect(walletService.getWalletCallCount == 1)
    }

    @Test func buildsAPhoneLocatorThatIgnoresTheChannel() {
        #expect(SignerConfig.phone("+14155552671", channel: .whatsapp).locator == .phone("+14155552671"))
        #expect(SignerConfig.phone("+14155552671").locator == .phone("+14155552671"))
    }

    private func makeEVMWallet(fileName: String) throws -> (EVMWallet, MockSmartWalletService) {
        let baseModel: WalletApiModel = try GetFromFile.getModelFrom(fileName: fileName, bundle: Bundle.module)
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

    @Suite("when the wallet cannot be fetched")
    struct NetworkOutageTests {
        private let parent = WalletUseSignerTests()
        private let outageMessage = "503 Service Unavailable"

        private func makeSolanaEmailWallet() throws -> (SolanaWallet, MockSmartWalletService) {
            let baseModel: WalletApiModel = try GetFromFile.getModelFrom(
                fileName: "WalletSolanaEmail",
                bundle: Bundle.module
            )
            let walletService = MockSmartWalletService()
            let wallet = try SolanaWallet(
                smartWalletService: walletService,
                signer: MockSigner(),
                baseModel: baseModel,
                solanaChain: .solana
            )
            return (wallet, walletService)
        }

        private func isOutage(_ error: any Error) -> Bool {
            guard case .walletGeneric(let message) = error as? WalletError else { return false }
            return message == outageMessage
        }

        @Test func selectsTheRecoveryEmailSignerWithoutFetchingTheWallet() async throws {
            let (wallet, walletService) = try makeSolanaEmailWallet()
            walletService.getWalletError = .walletGeneric(outageMessage)

            try await wallet.useSigner(.email("solana.user@example.com"))

            #expect(await wallet.selectedSigner?.locator == .email("solana.user@example.com"))
            #expect(walletService.getWalletCallCount == 0)
        }

        @Test func selectsTheRecoveryPhoneSignerWithoutFetchingTheWallet() async throws {
            let (wallet, walletService) = try parent.makePhoneWallet()
            walletService.getWalletError = .walletGeneric(outageMessage)

            try await wallet.useSigner(.phone("+14155552671"))

            #expect(await wallet.selectedSigner?.locator == .phone("+14155552671"))
            #expect(walletService.getWalletCallCount == 0)
        }

        @Test func selectsTheRecoveryApiKeySignerWithoutFetchingTheWallet() async throws {
            let (wallet, walletService) = try parent.makeEVMWallet(fileName: "WalletEVMApiKey")
            walletService.getWalletError = .walletGeneric(outageMessage)

            try await wallet.useSigner(.apiKey)

            #expect(wallet.selectedSigner is ApiKeySigner)
            #expect(walletService.getWalletCallCount == 0)
        }

        @Test func throwsTheNetworkErrorForADelegatedSigner() async throws {
            let (wallet, walletService) = try makeSolanaEmailWallet()
            walletService.getWalletError = .walletGeneric(outageMessage)

            await #expect { try await wallet.useSigner(.email("other@example.com")) } throws: { error in
                isOutage(error)
            }
            #expect(wallet.selectedSigner == nil)
        }

        @Test func throwsTheNetworkErrorForAPasskeySigner() async throws {
            let (wallet, walletService) = try parent.makeEVMWallet(fileName: "WalletPasskey")
            walletService.getWalletError = .walletGeneric(outageMessage)

            await #expect {
                try await wallet.useSigner(.passkey(name: "someone@paella.dev", host: "paella.dev"))
            } throws: { error in
                isOutage(error)
            }
            #expect(wallet.selectedSigner == nil)
        }
    }
}
