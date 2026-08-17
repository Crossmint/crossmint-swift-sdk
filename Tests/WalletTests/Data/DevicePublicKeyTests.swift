import Foundation
import Testing

@testable import Wallet

@Suite("Device Public Key", .tags(.unit))
struct DevicePublicKeyTests {
    @Test
    func splitsUncompressedKeyIntoHexCoordinates() throws {
        let rawKey = Data([0x04]) + Data((0..<64).map { UInt8($0) })

        let publicKey = try #require(DevicePublicKey(publicKeyBase64: rawKey.base64EncodedString()))

        #expect(publicKey.x == "0x000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f")
        #expect(publicKey.y == "0x202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f")
    }

    @Test
    func rejectsKeyWithoutUncompressedPrefix() {
        let rawKey = Data([0x02]) + Data(repeating: 0xab, count: 64)

        #expect(DevicePublicKey(publicKeyBase64: rawKey.base64EncodedString()) == nil)
    }

    @Test
    func rejectsKeyWithWrongLength() {
        let rawKey = Data([0x04]) + Data(repeating: 0xab, count: 32)

        #expect(DevicePublicKey(publicKeyBase64: rawKey.base64EncodedString()) == nil)
    }

    @Test
    func rejectsInvalidBase64() {
        #expect(DevicePublicKey(publicKeyBase64: "not base64!") == nil)
    }
}
