//
//  CrossmintWalletsRecoveryOverloadTests.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 09/09/26.
//

import CrossmintCommonTypes
import Foundation
import Testing
import TestsUtils

@testable import Wallet

/// Records what the chain-typed list overloads hand to the protocol's `[any Signer]` entry points.
private final class SpyCrossmintWallets: CrossmintWallets, @unchecked Sendable {
    var receivedChain: Chain?
    var receivedSigners: [any Signer] = []
    var wallet: Wallet?

    func getWallet(chain: Chain, recovery: any Signer, options: WalletOptions?) async throws(WalletError) -> Wallet? {
        throw .walletGeneric("unexpected single-signer call")
    }

    func getWallet(chain: Chain, recovery: [any Signer], options: WalletOptions?) async throws(WalletError) -> Wallet? {
        receivedChain = chain
        receivedSigners = recovery
        return wallet
    }

    func createWallet(chain: Chain, recovery: any Signer, options: WalletOptions?) async throws(WalletError) -> Wallet {
        throw .walletGeneric("unexpected single-signer call")
    }

    func createWallet(
        chain: Chain,
        recovery: [any Signer],
        options: WalletOptions?
    ) async throws(WalletError) -> Wallet {
        receivedChain = chain
        receivedSigners = recovery
        guard let wallet else { throw .walletGeneric("no wallet configured") }
        return wallet
    }
}

@Suite("CrossmintWallets recovery list overloads", .tags(.unit))
struct CrossmintWalletsRecoveryOverloadTests {
    private func makeSolanaWallet() throws -> SolanaWallet {
        let baseModel: WalletApiModel = try GetFromFile.getModelFrom(
            fileName: "WalletSolanaRecoveryMethods",
            bundle: Bundle.module
        )
        return try SolanaWallet(
            smartWalletService: MockSmartWalletService(),
            signer: MockSigner(),
            baseModel: baseModel,
            solanaChain: .solana
        )
    }

    private func makeStellarWallet() throws -> StellarWallet {
        let baseModel: WalletApiModel = try GetFromFile.getModelFrom(
            fileName: "WalletStellarRecoveryMethods",
            bundle: Bundle.module
        )
        return try StellarWallet(
            smartWalletService: MockSmartWalletService(),
            signer: MockSigner(),
            baseModel: baseModel,
            stellarChain: .stellar
        )
    }

    @Test func solanaCreateOverloadBuildsOneSignerPerEntryInOrder() async throws {
        let spy = SpyCrossmintWallets()
        spy.wallet = try makeSolanaWallet()

        let wallet = try await spy.createWallet(
            chain: SolanaChain.solana,
            recovery: [.email("alice@example.com"), .phone("+14155552671")]
        )

        #expect(spy.receivedChain?.name == "solana")
        #expect(spy.receivedSigners.map(\.signerType) == [.email, .phone])
        #expect(spy.receivedSigners[0] is SolanaEmailSigner)
        #expect(wallet.recoveryMethods.count == 3)
    }

    @Test func stellarGetOverloadBuildsStellarSigners() async throws {
        let spy = SpyCrossmintWallets()
        spy.wallet = try makeStellarWallet()

        let wallet = try await spy.getWallet(
            chain: StellarChain.stellar,
            recovery: [.email("alice@example.com"), .apiKey]
        )

        #expect(wallet != nil)
        #expect(spy.receivedSigners.map(\.signerType) == [.email, .apiKey])
        #expect(spy.receivedSigners[0] is StellarEmailSigner)
    }

    @Test func getOverloadPassesANilWalletThrough() async throws {
        let spy = SpyCrossmintWallets()

        let wallet = try await spy.getWallet(chain: SolanaChain.solana, recovery: [.email("alice@example.com")])

        #expect(wallet == nil)
        #expect(spy.receivedSigners.count == 1)
    }
}
