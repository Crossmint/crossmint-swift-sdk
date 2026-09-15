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

/// A conformer written before the recovery list entry points existed.
private final class SingleSignerCrossmintWallets: CrossmintWallets, @unchecked Sendable {
    var receivedSigner: (any Signer)?
    var wallet: Wallet?

    func getWallet(chain: Chain, recovery: any Signer, options: WalletOptions?) async throws(WalletError) -> Wallet? {
        receivedSigner = recovery
        return wallet
    }

    func createWallet(chain: Chain, recovery: any Signer, options: WalletOptions?) async throws(WalletError) -> Wallet {
        receivedSigner = recovery
        guard let wallet else { throw .walletGeneric("no wallet configured") }
        return wallet
    }
}

@Suite("CrossmintWallets recovery list overloads", .tags(.unit))
struct CrossmintWalletsRecoveryOverloadTests {
    fileprivate func makeSolanaWallet() throws -> SolanaWallet {
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

    @Test func solanaCreateOverloadBuildsOneSignerPerEntryInOrder() async throws {
        let spy = SpyCrossmintWallets()
        spy.wallet = try makeSolanaWallet()

        _ = try await spy.createWallet(
            chain: SolanaChain.solana,
            recovery: [.email("alice@example.com"), .phone("+14155552671")]
        )

        #expect(spy.receivedChain?.name == "solana")
        #expect(spy.receivedSigners.map(\.signerType) == [.email, .phone])
        #expect(spy.receivedSigners[0] is SolanaEmailSigner)
    }

    @Suite("when the conformer predates recovery lists")
    struct SingleSignerConformerTests {
        private let parent = CrossmintWalletsRecoveryOverloadTests()

        @Test func routesAOneSignerListThroughTheSingleSignerEntryPoint() async throws {
            let wallets = SingleSignerCrossmintWallets()
            wallets.wallet = try parent.makeSolanaWallet()

            _ = try await wallets.createWallet(chain: SolanaChain.solana, recovery: [.email("alice@example.com")])

            #expect(wallets.receivedSigner is SolanaEmailSigner)
        }

        @Test func rejectsALongerListBeforeAnyCall() async throws {
            let wallets = SingleSignerCrossmintWallets()

            await #expect(throws: WalletError.self) {
                _ = try await wallets.getWallet(
                    chain: SolanaChain.solana,
                    recovery: [.email("alice@example.com"), .phone("+14155552671")]
                )
            }
            #expect(wallets.receivedSigner == nil)
        }
    }
}
