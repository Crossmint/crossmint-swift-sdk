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

    @Test func returnsNilLocatorWithoutAKey() async {
        let signer = DeviceSigner(storage: MockDeviceSignerKeyStorage(), address: address)

        #expect(await signer.locator == nil)
    }

    @Test func derivesLocatorFromTheStoredKey() async throws {
        let storage = MockDeviceSignerKeyStorage()
        let publicKeyBase64 = try await storage.generateKey(address: address)
        let signer = DeviceSigner(storage: storage, address: address)

        #expect(await signer.locator == "device:\(publicKeyBase64)")
    }

    @Test func rejectsAPublicKeyThatIsNotUncompressedP256() {
        let compressedKey = Data([0x02] + [UInt8](repeating: 1, count: 32)).base64EncodedString()

        #expect(DeviceSigner.locator(forPublicKey: compressedKey) == nil)
        #expect(DeviceSigner.locator(forPublicKey: "not base64") == nil)
    }

    @Test func stampsApprovalsWithTheCurrentLocator() async throws {
        let storage = MockDeviceSignerKeyStorage()
        let publicKeyBase64 = try await storage.generateKey(address: address)
        let signer = DeviceSigner(storage: storage, address: address)

        let approvals = try await signer.approvals(for: "bWVzc2FnZQ==")

        let approval = try #require(approvals.first)
        guard case let .device(locator, signature) = approval else {
            Issue.record("Expected a device approval, got \(approval)")
            return
        }
        #expect(locator == "device:\(publicKeyBase64)")
        #expect(signature.r == "0xr")
        #expect(signature.s == "0xs")
    }

    @Test func throwsKeyNotFoundWithoutAKey() async {
        let signer = DeviceSigner(storage: MockDeviceSignerKeyStorage(), address: address)

        await #expect(throws: SignerError.device(.keyNotFound)) {
            try await signer.approvals(for: "bWVzc2FnZQ==")
        }
    }

    @Test func recognisesDeviceLocators() {
        #expect(DeviceSigner.handles("device:abc"))
        #expect(DeviceSigner.handles("email:user@example.com") == false)
    }
}
