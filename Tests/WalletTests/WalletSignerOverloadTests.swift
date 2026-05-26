//
//  WalletSignerOverloadTests.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 20/05/26.
//

import CrossmintCommonTypes
import Foundation
import Testing
@testable import Wallet

@Suite("DefaultCrossmintWallets WalletSigner overloads", .tags(.unit))
@MainActor struct WalletSignerOverloadTests {

    @Test("getWallet(signer:) returns existing wallet")
    func returnsExistingWallet() async throws {
        let service = MockSmartWalletService()
        service.getWalletResult = makeTestWalletApiModel(address: "0x1111111111111111111111111111111111111111")
        let wallets = DefaultCrossmintWallets(
            service: service,
            secureWalletStorage: MockSecureWalletStorage()
        )

        let wallet = try await wallets.getWallet(
            chain: Chain("base-sepolia"),
            signer: .email("test@example.com") { _ in }
        )

        #expect(wallet?.address == "0x1111111111111111111111111111111111111111")
        #expect(service.getWalletCallCount == 1)
        #expect(service.createWalletCallCount == 0)
    }

    @Test("getWallet(signer:) returns nil when wallet not found")
    func returnsNilWhenWalletNotFound() async throws {
        let service = MockSmartWalletService()
        service.getWalletResult = nil
        let wallets = DefaultCrossmintWallets(
            service: service,
            secureWalletStorage: MockSecureWalletStorage()
        )

        let wallet = try await wallets.getWallet(
            chain: Chain("base-sepolia"),
            signer: .email("test@example.com") { _ in }
        )

        #expect(wallet == nil)
        #expect(service.getWalletCallCount == 1)
        #expect(service.createWalletCallCount == 0)
    }

    @Test("createWallet(signer:) creates and returns wallet")
    func createsAndReturnsWallet() async throws {
        let service = MockSmartWalletService()
        service.createWalletResult = makeTestWalletApiModel(address: "0x2222222222222222222222222222222222222222")
        let wallets = DefaultCrossmintWallets(
            service: service,
            secureWalletStorage: MockSecureWalletStorage()
        )

        let wallet = try await wallets.createWallet(
            chain: Chain("base-sepolia"),
            signer: .email("test@example.com") { _ in }
        )

        #expect(wallet.address == "0x2222222222222222222222222222222222222222")
        #expect(service.getWalletCallCount == 0)
        #expect(service.createWalletCallCount == 1)
    }

    @Test("getWallet(signer:) propagates service errors")
    func propagatesGetWalletError() async throws {
        let service = MockSmartWalletService()
        service.getWalletShouldThrow = true
        let wallets = DefaultCrossmintWallets(
            service: service,
            secureWalletStorage: MockSecureWalletStorage()
        )

        await #expect(throws: WalletError.self) {
            _ = try await wallets.getWallet(
                chain: Chain("base-sepolia"),
                signer: .email("test@example.com") { _ in }
            )
        }
    }
}
