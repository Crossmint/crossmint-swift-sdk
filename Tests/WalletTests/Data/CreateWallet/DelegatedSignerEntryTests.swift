//
//  DelegatedSignerEntryTests.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 30/09/26.
//

import CrossmintCommonTypes
import Foundation
import Testing

@testable import Wallet

@Suite("Delegated signer entry encoding", .tags(.unit))
struct DelegatedSignerEntryTests {
    private func encode(_ signer: DelegatedSignerEntry.Signer) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let raw = try encoder.encode(DelegatedSignerEntry(signer: signer))
        return String(bytes: raw, encoding: .utf8) ?? ""
    }

    @Test func encodesAPasskeyAsATypedObjectUnderSigner() throws {
        let passkey = PasskeySignerData(id: "pk-id", name: "alice", publicKey: .init(x: "123", y: "456"))

        let json = try encode(.passkey(passkey))

        #expect(json == #"{"signer":{"id":"pk-id","name":"alice","publicKey":{"x":"123","y":"456"},"type":"passkey"}}"#)
    }
}
