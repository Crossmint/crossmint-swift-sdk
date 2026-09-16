//
//  DeviceSignerTests.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 04/09/26.
//

import DeviceSigner
import Foundation
import Testing

@testable import Wallet

@Suite("Device Signer", .tags(.unit))
struct WalletDeviceSignerTests {
    private let address = "7ZN9rAofFVVP1WKqfKozsVWQYcDj2u9juYyRkrKUVR8Y"
    private let storage = MockDeviceSignerKeyStorage()
    private var signer: DeviceSigner { DeviceSigner(storage: storage, address: address) }

    @Test func returnsNilLocatorWithoutAKey() async {
        #expect(await signer.locator == nil)
    }

    @Test func derivesLocatorFromTheStoredKey() async throws {
        let publicKeyBase64 = try await storage.generateKey(address: address)

        #expect(await signer.locator == .device(publicKey: publicKeyBase64))
    }

    @Test func returnsNilLocatorWhenTheStoredKeyIsNotUncompressedP256() async throws {
        let compressedKey = Data([0x02] + [UInt8](repeating: 1, count: 32)).base64EncodedString()
        try await storage.mapAddressToKey(address: address, publicKeyBase64: compressedKey)

        #expect(await signer.locator == nil)
    }

    @Test func stampsApprovalsWithTheCurrentLocator() async throws {
        let publicKeyBase64 = try await storage.generateKey(address: address)

        let approvals = try await signer.approvals(for: "bWVzc2FnZQ==")

        let (signer, signature) = try #require(approvals.first?.device)
        #expect(signer == "device:\(publicKeyBase64)")
        #expect((signature.r, signature.s) == ("0xr", "0xs"))
    }

    @Test func throwsKeyNotFoundWithoutAKey() async {
        await #expect(throws: SignerError.device(.keyNotFound)) {
            try await signer.approvals(for: "bWVzc2FnZQ==")
        }
    }
}
