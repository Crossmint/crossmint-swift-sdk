//
//  RecoverySignerListCreationTests.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 09/09/26.
//

import CrossmintCommonTypes
import Foundation
import SecureStorage
import Testing
import TestsUtils

@testable import Wallet

@Suite("Wallet Creation with a recovery signer list", .tags(.unit))
struct RecoverySignerListCreationTests {
    private final class StubSecureWalletStorage: SecureWalletStorage, @unchecked Sendable {
        func savePrivateKey(_ privateKey: String, forEmail email: String) {}
        func getPrivateKey(forEmail email: String) -> String? { nil }
    }

    private let walletService = MockSmartWalletService()

    private func makeWallets() -> DefaultCrossmintWallets {
        DefaultCrossmintWallets(
            service: walletService,
            secureWalletStorage: StubSecureWalletStorage(),
            deviceSignerKeyStorage: MockDeviceSignerKeyStorage()
        )
    }

    private func loadFixture(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json"))
        return try Data(contentsOf: url)
    }

    @Test func sendsTheListUnderRecoveryAndNoAdminSigner() async throws {
        walletService.createWalletFixture = try loadFixture("WalletSolanaRecoveryMethods")
        let alice = MockSigner(email: "alice@example.com")
        let bob = MockSigner(email: "bob@example.com")

        _ = try await makeWallets().createWallet(chain: Chain("solana"), recovery: [alice, bob], options: nil)

        let config = try #require(walletService.lastCreateWalletParams?.config)
        #expect(config.adminSigner == nil)
        #expect(config.recovery?.count == 2)
    }

    @Test func sendsASingleSignerUnderAdminSigner() async throws {
        walletService.createWalletFixture = try loadFixture("WalletSolanaEmail")

        _ = try await makeWallets().createWallet(chain: Chain("solana"), recovery: MockSigner(), options: nil)

        let config = try #require(walletService.lastCreateWalletParams?.config)
        #expect(config.adminSigner != nil)
        #expect(config.recovery == nil)
    }

    @Test func keepsAOneElementListUnderRecovery() async throws {
        walletService.createWalletFixture = try loadFixture("WalletSolanaEmail")

        _ = try await makeWallets().createWallet(chain: Chain("solana"), recovery: [MockSigner()], options: nil)

        let config = try #require(walletService.lastCreateWalletParams?.config)
        #expect(config.adminSigner == nil)
        #expect(config.recovery?.count == 1)
    }

    @Test func initializesEverySignerBeforeCreating() async throws {
        walletService.createWalletFixture = try loadFixture("WalletStellarRecoveryMethods")
        let alice = MockSigner(email: "alice@example.com")
        let bob = MockSigner(email: "bob@example.com")

        _ = try await makeWallets().createWallet(chain: Chain("stellar"), recovery: [alice, bob], options: nil)

        #expect(alice.initializeCallCount == 1)
        #expect(bob.initializeCallCount == 1)
    }

    @Test func signsWithTheFirstSignerOfTheList() async throws {
        walletService.createWalletFixture = try loadFixture("WalletSolanaRecoveryMethods")
        let alice = MockSigner(email: "alice@example.com")
        let bob = MockSigner(email: "bob@example.com")

        let wallet = try await makeWallets().createWallet(chain: Chain("solana"), recovery: [alice, bob], options: nil)

        #expect(wallet.signer as? MockSigner === alice)
    }

    @Test func rejectsAnEmptyList() async throws {
        let wallets = makeWallets()

        await #expect {
            _ = try await wallets.createWallet(chain: Chain("solana"), recovery: [any Signer](), options: nil)
        } throws: { error in
            guard case .walletGeneric = error as? WalletError else { return false }
            return true
        }
        #expect(walletService.createWalletCallCount == 0)
    }

    @Test func rejectsAListOnEVMBeforeCallingTheApi() async throws {
        let wallets = makeWallets()

        await #expect {
            _ = try await wallets.createWallet(
                chain: Chain("base-sepolia"),
                recovery: [MockSigner(email: "alice@example.com"), MockSigner(email: "bob@example.com")],
                options: nil
            )
        } throws: { error in
            guard case .recoveryConfigRejected(let code, _) = error as? WalletError else { return false }
            return code == WalletError.RECOVERY_NOT_SUPPORTED_ON_CHAIN
        }
        #expect(walletService.createWalletCallCount == 0)
    }

    @Test func loadsAnExistingWalletWithAList() async throws {
        walletService.getWalletFixture = try loadFixture("WalletSolanaRecoveryMethods")
        let alice = MockSigner(email: "alice@example.com")
        let bob = MockSigner(email: "bob@example.com")

        let wallet = try #require(
            try await makeWallets().getWallet(chain: Chain("solana"), recovery: [alice, bob], options: nil)
        )

        #expect(wallet.recoveryMethods.count == 3)
        #expect(wallet.signer as? MockSigner === alice)
    }
}
