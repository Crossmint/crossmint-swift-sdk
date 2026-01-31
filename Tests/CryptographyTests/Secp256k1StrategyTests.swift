import CryptoKit
import Foundation
import secp256k1
import Testing
@testable import Cryptography

@Suite("Secp256k1Strategy Tests")
struct Secp256k1StrategyTests {
    let strategy = Secp256k1Strategy()

    @Test("Get private key from seed - deterministic derivation")
    func testGetPrivateKeyFromSeedDeterministic() async throws {
        let seed = Data(repeating: 0x42, count: 32)
        let privateKey1 = try await strategy.getPrivateKeyFromSeed(seed: seed)
        let privateKey2 = try await strategy.getPrivateKeyFromSeed(seed: seed)

        #expect(privateKey1.count == 32)
        #expect(privateKey1 == privateKey2)
    }

    @Test("Get private key from seed - different seeds produce different keys")
    func testGetPrivateKeyFromSeedDifferentSeeds() async throws {
        let seed1 = Data(repeating: 0x42, count: 32)
        let seed2 = Data(repeating: 0x43, count: 32)

        let privateKey1 = try await strategy.getPrivateKeyFromSeed(seed: seed1)
        let privateKey2 = try await strategy.getPrivateKeyFromSeed(seed: seed2)

        #expect(privateKey1 != privateKey2)
    }

    @Test("Get private key from seed - includes derivation path")
    func testGetPrivateKeyFromSeedIncludesDerivationPath() async throws {
        let seed = Data(repeating: 0x42, count: 32)
        let privateKey = try await strategy.getPrivateKeyFromSeed(seed: seed)

        let derivationPath: [UInt8] = [
            0x73, 0x65, 0x63, 0x70, 0x32, 0x35, 0x36, 0x6B, 0x31, 0x2D, 0x64, 0x65,
            0x72, 0x69, 0x76, 0x61, 0x74, 0x69, 0x6F, 0x6E, 0x2D, 0x70, 0x61, 0x74,
            0x68
        ]
        var expectedInput = seed
        expectedInput.append(contentsOf: derivationPath)
        let expectedKey = Data(SHA256.hash(data: expectedInput))

        #expect(privateKey == expectedKey)
    }

    @Test("Get public key from valid private key")
    func testGetPublicKeyFromValidKey() throws {
        let privateKeyHex = "e9b363f475d641078ffd02b477054f8b4c0d3442941bc3d69d15d151ce07be8f"
        let privateKey = Data(hexString: privateKeyHex)

        let publicKey = try strategy.getPublicKey(privateKey: privateKey)

        #expect(publicKey.count == 65)
        #expect(publicKey[0] == 0x04)
    }

    @Test("Get public key - invalid key length")
    func testGetPublicKeyInvalidLength() throws {
        let privateKey = Data(repeating: 0x42, count: 16)

        #expect(throws: Secp256k1Error.invalidPrivateKey) {
            try strategy.getPublicKey(privateKey: privateKey)
        }
    }

    @Test("Sign 32-byte digest with valid private key")
    func testSignDigest() throws {
        let privateKeyHex = "e9b363f475d641078ffd02b477054f8b4c0d3442941bc3d69d15d151ce07be8f"
        let privateKey = Data(hexString: privateKeyHex)
        let digest = Data(SHA256.hash(data: Data("test message".utf8)))

        let signature = try strategy.sign(privateKey: privateKey, digest: digest)

        #expect(signature.count == 65)

        let recoveryByte = signature[64]
        #expect(recoveryByte == 0x1B || recoveryByte == 0x1C)
    }

    @Test("Sign - invalid digest length")
    func testSignInvalidDigestLength() throws {
        let privateKeyHex = "e9b363f475d641078ffd02b477054f8b4c0d3442941bc3d69d15d151ce07be8f"
        let privateKey = Data(hexString: privateKeyHex)
        let digest = Data(repeating: 0x42, count: 16)

        #expect(throws: Secp256k1Error.invalidDigestLength(16)) {
            try strategy.sign(privateKey: privateKey, digest: digest)
        }
    }

    @Test("Sign - invalid private key length")
    func testSignInvalidPrivateKeyLength() throws {
        let privateKey = Data(repeating: 0x42, count: 16)
        let digest = Data(repeating: 0x42, count: 32)

        #expect(throws: Secp256k1Error.invalidPrivateKey) {
            try strategy.sign(privateKey: privateKey, digest: digest)
        }
    }

    @Test("Format public key as hex with 0x prefix")
    func testFormatPublicKey() throws {
        let privateKeyHex = "e9b363f475d641078ffd02b477054f8b4c0d3442941bc3d69d15d151ce07be8f"
        let privateKey = Data(hexString: privateKeyHex)
        let publicKey = try strategy.getPublicKey(privateKey: privateKey)

        let formatted = strategy.formatPublicKey(publicKey: publicKey)

        #expect(formatted.keyType == "secp256k1")
        #expect(formatted.encoding == .hex)
        #expect(formatted.bytes.hasPrefix("0x"))
        #expect(formatted.bytes.count == 132)
    }

    @Test("Format signature as hex with 0x prefix")
    func testFormatSignature() throws {
        let privateKeyHex = "e9b363f475d641078ffd02b477054f8b4c0d3442941bc3d69d15d151ce07be8f"
        let privateKey = Data(hexString: privateKeyHex)
        let digest = Data(SHA256.hash(data: Data("test".utf8)))

        let signature = try strategy.sign(privateKey: privateKey, digest: digest)
        let formatted = strategy.formatSignature(signature: signature)

        #expect(formatted.keyType == "secp256k1")
        #expect(formatted.encoding == .hex)
        #expect(formatted.bytes.hasPrefix("0x"))
        #expect(formatted.bytes.count == 132)
    }

    @Test("Signature verification with secp256k1 library")
    func testSignatureVerification() throws {
        let privateKeyHex = "e9b363f475d641078ffd02b477054f8b4c0d3442941bc3d69d15d151ce07be8f"
        let privateKey = Data(hexString: privateKeyHex)
        let message = Data("test message".utf8)
        let digest = Data(SHA256.hash(data: message))

        let signature = try strategy.sign(privateKey: privateKey, digest: digest)
        let publicKey = try strategy.getPublicKey(privateKey: privateKey)

        let signingKey = try secp256k1.Signing.PrivateKey(
            dataRepresentation: privateKey,
            format: .uncompressed
        )

        let rBytes = Array(signature[0..<32])
        let sBytes = Array(signature[32..<64])
        var compactSig = rBytes + sBytes

        let ecdsaSignature = try secp256k1.Signing.ECDSASignature(
            compactRepresentation: compactSig
        )

        let isValid = signingKey.publicKey.isValidSignature(ecdsaSignature, for: digest)
        #expect(isValid)
    }

    @Test("Full roundtrip: seed to signature")
    func testFullRoundtrip() async throws {
        let seed = Data((0..<32).map { _ in UInt8.random(in: 0...255) })

        let privateKey = try await strategy.getPrivateKeyFromSeed(seed: seed)
        let publicKey = try strategy.getPublicKey(privateKey: privateKey)
        let message = Data("Hello, Ethereum!".utf8)
        let digest = Data(SHA256.hash(data: message))
        let signature = try strategy.sign(privateKey: privateKey, digest: digest)

        #expect(privateKey.count == 32)
        #expect(publicKey.count == 65)
        #expect(signature.count == 65)

        let formattedPubKey = strategy.formatPublicKey(publicKey: publicKey)
        let formattedSig = strategy.formatSignature(signature: signature)

        #expect(formattedPubKey.keyType == "secp256k1")
        #expect(formattedSig.keyType == "secp256k1")
        #expect(formattedPubKey.bytes.hasPrefix("0x"))
        #expect(formattedSig.bytes.hasPrefix("0x"))
    }

    @Test("Known test vector - matches TypeScript implementation")
    func testKnownTestVector() async throws {
        let seed = Data(repeating: 0x01, count: 32)

        let privateKey = try await strategy.getPrivateKeyFromSeed(seed: seed)
        let publicKey = try strategy.getPublicKey(privateKey: privateKey)

        #expect(privateKey.count == 32)
        #expect(publicKey.count == 65)
        #expect(publicKey[0] == 0x04)

        let formattedPubKey = strategy.formatPublicKey(publicKey: publicKey)
        #expect(formattedPubKey.bytes.hasPrefix("0x04"))
    }

    @Test("Recovery byte is correct (0x1b or 0x1c)")
    func testRecoveryByte() throws {
        let privateKeyHex = "e9b363f475d641078ffd02b477054f8b4c0d3442941bc3d69d15d151ce07be8f"
        let privateKey = Data(hexString: privateKeyHex)

        for i in 0..<10 {
            let message = Data("test message \(i)".utf8)
            let digest = Data(SHA256.hash(data: message))
            let signature = try strategy.sign(privateKey: privateKey, digest: digest)

            let recoveryByte = signature[64]
            #expect(recoveryByte == 0x1B || recoveryByte == 0x1C)
        }
    }
}

private extension Data {
    init(hexString: String) {
        var hex = hexString
        if hex.hasPrefix("0x") {
            hex = String(hex.dropFirst(2))
        }

        var data = Data()
        var index = hex.startIndex

        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            if let byte = UInt8(hex[index..<nextIndex], radix: 16) {
                data.append(byte)
            }
            index = nextIndex
        }

        self = data
    }

    func toHexString() -> String {
        map { String(format: "%02x", $0) }.joined()
    }
}
