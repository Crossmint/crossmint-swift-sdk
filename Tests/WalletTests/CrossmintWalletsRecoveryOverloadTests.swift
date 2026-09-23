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

/// A conformer that implements only the recovery list entry point.
private final class SpyCrossmintWallets: CrossmintWallets, @unchecked Sendable {
    var receivedChain: Chain?
    var receivedSigners: [any Signer] = []
    var wallet: Wallet?

    func createWallet(
        chain: Chain,
        recoveryMethods: [any Signer],
        options: WalletOptions?
    ) async throws(WalletError) -> Wallet {
        receivedChain = chain
        receivedSigners = recoveryMethods
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
            recoveryMethods: [.email("alice@example.com"), .phone("+14155552671")]
        )

        #expect(spy.receivedChain?.name == "solana")
        #expect(spy.receivedSigners.map(\.signerType) == [.email, .phone])
        #expect(spy.receivedSigners[0] is SolanaEmailSigner)
    }

    @Test func throwsFromTheGetWalletDefault() async throws {
        let wallets = SpyCrossmintWallets()

        await #expect(throws: WalletError.self) {
            _ = try await wallets.getWallet(chain: SolanaChain.solana)
        }
    }
}
