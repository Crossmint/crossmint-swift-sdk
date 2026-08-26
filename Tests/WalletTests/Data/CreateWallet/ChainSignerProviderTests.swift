//
//  ChainSignerProviderTests.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 26/08/26.
//

import CrossmintCommonTypes
import Foundation
import Testing

@testable import Wallet

/// Each provider hard-codes its own `chainType` when building a `PhoneSigner`, so a copy-paste
/// slip between the three would only surface as a wrong signature encoding at runtime.
@Suite("Chain Signer Providers", .tags(.unit))
@MainActor
struct ChainSignerProviderTests {
    @Test func evmProviderBuildsAnEVMPhoneSigner() async throws {
        let signer = try #require(EVMSigners.phone("+15551234567").signer as? PhoneSigner)
        #expect(await signer.keyType == "secp256k1")
        #expect(await signer.encoding == "hex")
    }

    @Test func solanaProviderBuildsASolanaPhoneSigner() async throws {
        let signer = try #require(SolanaSigners.phone("+15551234567").signer as? PhoneSigner)
        #expect(await signer.keyType == "ed25519")
        #expect(await signer.encoding == "base58")
    }

    @Test func stellarProviderBuildsAStellarPhoneSigner() async throws {
        let signer = try #require(StellarSigners.phone("+15551234567").signer as? PhoneSigner)
        #expect(await signer.keyType == "ed25519")
        #expect(await signer.encoding == "base64")
    }

    @Test func providersCarryTheRequestedChannelThrough() throws {
        let evm = try #require(EVMSigners.phone("+15551234567", channel: .whatsapp).signer as? PhoneSigner)
        let solana = try #require(SolanaSigners.phone("+15551234567", channel: .sms).signer as? PhoneSigner)
        let stellar = try #require(StellarSigners.phone("+15551234567").signer as? PhoneSigner)

        #expect(evm.channel == .whatsapp)
        #expect(solana.channel == .sms)
        #expect(stellar.channel == nil)
    }
}
