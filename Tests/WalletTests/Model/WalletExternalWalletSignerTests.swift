//
//  WalletExternalWalletSignerTests.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 24/09/26.
//

import CrossmintCommonTypes
import Foundation
import Testing
import TestsUtils

@testable import Wallet

private let RECOVERY_ADDRESS = "EX2jMfAdfUKSqh7415jsTzGE1KMepXPeqM4vXyCpVXGc"
private let DELEGATED_ADDRESS = "0x1234567890123456789012345678901234567890"

private actor SignPayloadRecorder {
    private(set) var payloads: [String] = []

    func record(_ payload: String) {
        payloads.append(payload)
    }
}

private struct ExternalWalletFailure: Error {}

@Suite("External wallet signer", .tags(.unit))
struct WalletExternalWalletSignerTests {
    private let walletService = MockSmartWalletService()

    private func makeRecoveryWallet() throws -> SolanaWallet {
        let baseModel: WalletApiModel = try GetFromFile.getModelFrom(
            fileName: "WalletSolanaKeypair",
            bundle: Bundle.module
        )
        return try SolanaWallet(
            smartWalletService: walletService,
            signer: MockSigner(),
            baseModel: baseModel,
            solanaChain: .solana
        )
    }

    private func makeDelegatedWallet() throws -> EVMWallet {
        let baseModel: WalletApiModel = try GetFromFile.getModelFrom(
            fileName: "WalletEVMEmail",
            bundle: Bundle.module
        )
        let url = try #require(Bundle.module.url(forResource: "WalletEVMEmail", withExtension: "json"))
        walletService.getWalletFixture = try Data(contentsOf: url)
        walletService.getWalletSignerLocators = ["external-wallet:\(DELEGATED_ADDRESS)"]
        return try EVMWallet(
            smartWalletService: walletService,
            signer: MockSigner(),
            baseModel: baseModel,
            evmChain: .polygon
        )
    }

    @Test func selectsTheRecoverySigner() async throws {
        let wallet = try makeRecoveryWallet()

        try await wallet.useSigner(.externalWallet(RECOVERY_ADDRESS, onSign: { _ in "signature" }))

        #expect(await wallet.selectedSigner?.locator == .externalWallet(address: RECOVERY_ADDRESS))
    }

    @Test func selectsARegisteredDelegatedSigner() async throws {
        let wallet = try makeDelegatedWallet()

        try await wallet.useSigner(.externalWallet(DELEGATED_ADDRESS, onSign: { _ in "0xsignature" }))

        #expect(await wallet.selectedSigner?.locator == .externalWallet(address: DELEGATED_ADDRESS))
    }

    @Test func rejectsASignerWithoutAnOnSignCallback() async throws {
        let wallet = try makeRecoveryWallet()

        await #expect { try await wallet.useSigner(.externalWallet(RECOVERY_ADDRESS)) } throws: { error in
            guard case .signerCallbackMissing(let locator) = error as? WalletError else { return false }
            return locator == "external-wallet:\(RECOVERY_ADDRESS)"
        }
        #expect(wallet.selectedSigner == nil)
    }

    @Test func rejectsAnAddressThatIsNotRegisteredOnTheWallet() async throws {
        let wallet = try makeDelegatedWallet()
        let unknownAddress = "0x0000000000000000000000000000000000000001"

        await #expect {
            try await wallet.useSigner(.externalWallet(unknownAddress, onSign: { _ in "0xsignature" }))
        } throws: { error in
            guard case .signerNotRegistered(let locator) = error as? WalletError else { return false }
            return locator == "external-wallet:\(unknownAddress)"
        }
        #expect(wallet.selectedSigner == nil)
    }

    @Test func signsThePendingApprovalWithTheOnSignCallback() async throws {
        let wallet = try makeRecoveryWallet()
        let recorder = SignPayloadRecorder()
        let payload = "3Bxs4Bc3VYuGVB19"
        try await wallet.useSigner(.externalWallet(RECOVERY_ADDRESS, onSign: { message in
            await recorder.record(message)
            return "5VERv8NMvzbJMEkV8xnrLkEaWRtSz9CosKDYjCJjBRnbJLgp8uirBgmQpjKhoR4tjF3ZpRzrFmBV6UjKdiSZkQUW"
        }))

        let request = try await wallet.makeSignRequest(for: "external-wallet:\(RECOVERY_ADDRESS)", message: payload)

        #expect(await recorder.payloads == [payload])
        guard case let .keypair(signer, signature) = try #require(request.approvals.first) else {
            Issue.record("Expected a keypair approval")
            return
        }
        #expect(signer == "external-wallet:\(RECOVERY_ADDRESS)")
        #expect(signature == "5VERv8NMvzbJMEkV8xnrLkEaWRtSz9CosKDYjCJjBRnbJLgp8uirBgmQpjKhoR4tjF3ZpRzrFmBV6UjKdiSZkQUW")
    }

    @Test(arguments: [
        (SignerError.cancelled as any Error, SignerError.cancelled),
        (CancellationError() as any Error, SignerError.cancelled),
        (ExternalWalletFailure() as any Error, SignerError.signingFailed)
    ])
    func mapsAnOnSignFailureToASignerError(thrown: any Error, expected: SignerError) async throws {
        let signer = ExternalWalletSigner(address: RECOVERY_ADDRESS, onSign: { _ in throw thrown })

        await #expect(throws: expected) {
            _ = try await signer.sign(message: "payload")
        }
    }
}
