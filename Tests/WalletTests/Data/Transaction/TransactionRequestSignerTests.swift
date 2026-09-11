//
//  TransactionRequestSignerTests.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 09/09/26.
//

import Foundation
import Testing

@testable import Wallet

@Suite("Transaction request signer", .tags(.unit))
struct TransactionRequestSignerTests {
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return encoder
    }()

    private func encode(_ request: some Encodable) throws -> String {
        String(bytes: try encoder.encode(request), encoding: .utf8) ?? ""
    }

    @Test func solanaRequestNamesTheSigner() throws {
        let json = try encode(CreateSolanaTransactionRequest(transaction: "AQ==", signer: "phone:+14155552671"))

        #expect(json == #"{"params":{"signer":"phone:+14155552671","transaction":"AQ=="}}"#)
    }

    @Test func solanaRequestDecodesTheSigner() throws {
        let json = Data(#"{"params":{"transaction":"AQ==","signer":"phone:+14155552671"}}"#.utf8)

        let request = try JSONDecoder().decode(CreateSolanaTransactionRequest.self, from: json)

        #expect(request.signer == "phone:+14155552671")
    }

    @Test func stellarRequestDecodesWithoutASigner() throws {
        let json = Data(#"{"params":{"transaction":"AQ=="}}"#.utf8)

        let request = try JSONDecoder().decode(CreateStellarTransactionRequest.self, from: json)

        #expect(request.signer == nil)
    }
}
