//
//  CreateWalletParamsTests.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 09/09/26.
//

import CrossmintCommonTypes
import Foundation
import Testing

@testable import Wallet

@Suite("Create wallet request body", .tags(.unit))
struct CreateWalletParamsTests {
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return encoder
    }()

    private func encode(_ config: CreateWalletParams.InputConfig) throws -> String {
        String(bytes: try encoder.encode(config), encoding: .utf8) ?? ""
    }

    @Test func encodesASingleSignerUnderAdminSignerOnly() throws {
        let json = try encode(.init(adminSigner: EmailSignerData(email: "alice@example.com"), delegatedSigners: nil))

        #expect(json == #"{"adminSigner":{"email":"alice@example.com","type":"email"}}"#)
    }

    @Test func encodesAListUnderRecoveryOnly() throws {
        let json = try encode(.init(
            recovery: [EmailSignerData(email: "alice@example.com"), PhoneSignerData(phone: "+14155552671")],
            delegatedSigners: nil
        ))

        let expected = #"{"recovery":[{"email":"alice@example.com","type":"email"},"#
            + #"{"phone":"+14155552671","type":"phone"}]}"#
        #expect(json == expected)
    }

    @Test func keepsDelegatedSignersNextToTheRecoveryList() throws {
        let json = try encode(.init(
            recovery: [EmailSignerData(email: "alice@example.com")],
            delegatedSigners: [DelegatedSignerEntry(signer: "device:abc")]
        ))

        let expected = #"{"delegatedSigners":[{"signer":"device:abc"}],"#
            + #""recovery":[{"email":"alice@example.com","type":"email"}]}"#
        #expect(json == expected)
    }
}
