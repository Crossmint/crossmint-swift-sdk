import CryptoKit
import Foundation
import Testing
@testable import Cryptography

@Suite("Ed25519Strategy Tests")
struct Ed25519StrategyTests {
    let strategy = Ed25519Strategy()

    @Test("Get private key from seed - valid 32 byte seed")
    func testGetPrivateKeyFromSeed32Bytes() throws {
        let seed = Data(repeating: 0x42, count: 32)
        let privateKey = try strategy.getPrivateKeyFromSeed(seed: seed)

        #expect(privateKey.count == 32)
        #expect(privateKey == seed)
    }

    @Test("Get private key from seed - valid 64 byte seed")
    func testGetPrivateKeyFromSeed64Bytes() throws {
        let seed = Data(repeating: 0x42, count: 64)
        let privateKey = try strategy.getPrivateKeyFromSeed(seed: seed)

        #expect(privateKey.count == 32)
        #expect(privateKey == Data(repeating: 0x42, count: 32))
    }

    @Test("Get private key from seed - invalid seed length")
    func testGetPrivateKeyFromSeedInvalidLength() throws {
        let seed = Data(repeating: 0x42, count: 16)

        #expect(throws: Ed25519Error.invalidSeedLength(16)) {
            try strategy.getPrivateKeyFromSeed(seed: seed)
        }
    }

    @Test("Get public key from 32 byte private key")
    func testGetPublicKeyFrom32ByteKey() throws {
        let privateKeyHex = "9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60"
        let privateKey = Data(hexString: privateKeyHex)
        let publicKey = try strategy.getPublicKey(privateKey: privateKey)

        #expect(publicKey.count == 32)

        let expectedPublicKeyHex = "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a"
        #expect(publicKey.toHexString() == expectedPublicKeyHex)
    }

    @Test("Get public key from 64 byte private key (Solana format)")
    func testGetPublicKeyFrom64ByteKey() throws {
        let privateKeyHex = "9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60"
        let expectedPublicKeyHex = "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a"

        var fullKey = Data(hexString: privateKeyHex)
        fullKey.append(Data(hexString: expectedPublicKeyHex))

        let publicKey = try strategy.getPublicKey(privateKey: fullKey)

        #expect(publicKey.count == 32)
        #expect(publicKey.toHexString() == expectedPublicKeyHex)
    }

    @Test("Get public key - invalid key length")
    func testGetPublicKeyInvalidLength() throws {
        let privateKey = Data(repeating: 0x42, count: 16)

        #expect(throws: Ed25519Error.invalidKeyLength(16)) {
            try strategy.getPublicKey(privateKey: privateKey)
        }
    }

    @Test("Sign message with valid private key")
    func testSignMessage() throws {
        let privateKeyHex = "9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60"
        let privateKey = Data(hexString: privateKeyHex)
        let message = Data("test message".utf8)

        let signature = try strategy.sign(privateKey: privateKey, message: message)

        #expect(signature.count == 64)

        let publicKey = try strategy.getPublicKey(privateKey: privateKey)
        let signingPublicKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicKey)
        #expect(signingPublicKey.isValidSignature(signature, for: message))
    }

    @Test("Sign empty message")
    func testSignEmptyMessage() throws {
        let privateKeyHex = "9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60"
        let privateKey = Data(hexString: privateKeyHex)
        let message = Data()

        let signature = try strategy.sign(privateKey: privateKey, message: message)

        #expect(signature.count == 64)

        let publicKey = try strategy.getPublicKey(privateKey: privateKey)
        let signingPublicKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicKey)
        #expect(signingPublicKey.isValidSignature(signature, for: message))
    }

    @Test("Sign with 64 byte key extracts first 32 bytes")
    func testSignWith64ByteKey() throws {
        let privateKeyHex = "9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60"
        let expectedPublicKeyHex = "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a"

        var fullKey = Data(hexString: privateKeyHex)
        fullKey.append(Data(hexString: expectedPublicKeyHex))

        let message = Data("test message".utf8)
        let signature = try strategy.sign(privateKey: fullKey, message: message)

        #expect(signature.count == 64)

        let publicKey = Data(hexString: expectedPublicKeyHex)
        let signingPublicKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicKey)
        #expect(signingPublicKey.isValidSignature(signature, for: message))
    }

    @Test("Sign - invalid key length")
    func testSignInvalidKeyLength() throws {
        let privateKey = Data(repeating: 0x42, count: 16)
        let message = Data("test".utf8)

        #expect(throws: Ed25519Error.invalidKeyLength(16)) {
            try strategy.sign(privateKey: privateKey, message: message)
        }
    }

    @Test("Format public key as base58")
    func testFormatPublicKeyBase58() throws {
        let publicKeyHex = "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a"
        let publicKey = Data(hexString: publicKeyHex)

        let formatted = try strategy.formatPublicKey(publicKey: publicKey, encoding: .base58)

        #expect(formatted.keyType == "ed25519")
        #expect(formatted.encoding == .base58)
        #expect(!formatted.bytes.isEmpty)
    }

    @Test("Format public key as hex")
    func testFormatPublicKeyHex() throws {
        let publicKeyHex = "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a"
        let publicKey = Data(hexString: publicKeyHex)

        let formatted = try strategy.formatPublicKey(publicKey: publicKey, encoding: .hex)

        #expect(formatted.keyType == "ed25519")
        #expect(formatted.encoding == .hex)
        #expect(formatted.bytes == publicKeyHex)
    }

    @Test("Format signature as base58")
    func testFormatSignatureBase58() throws {
        let privateKeyHex = "9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60"
        let privateKey = Data(hexString: privateKeyHex)
        let message = Data("test".utf8)

        let signature = try strategy.sign(privateKey: privateKey, message: message)
        let formatted = try strategy.formatSignature(signature: signature, encoding: .base58)

        #expect(formatted.keyType == "ed25519")
        #expect(formatted.encoding == .base58)
        #expect(!formatted.bytes.isEmpty)
    }

    @Test("Format signature as hex")
    func testFormatSignatureHex() throws {
        let privateKeyHex = "9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60"
        let privateKey = Data(hexString: privateKeyHex)
        let message = Data("test".utf8)

        let signature = try strategy.sign(privateKey: privateKey, message: message)
        let formatted = try strategy.formatSignature(signature: signature, encoding: .hex)

        #expect(formatted.keyType == "ed25519")
        #expect(formatted.encoding == .hex)
        #expect(formatted.bytes.count == 128)
    }

    @Test("Full roundtrip: seed to signature verification")
    func testFullRoundtrip() throws {
        let seed = Data((0..<32).map { _ in UInt8.random(in: 0...255) })

        let privateKey = try strategy.getPrivateKeyFromSeed(seed: seed)
        let publicKey = try strategy.getPublicKey(privateKey: privateKey)
        let message = Data("Hello, Solana!".utf8)
        let signature = try strategy.sign(privateKey: privateKey, message: message)

        let signingPublicKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicKey)
        #expect(signingPublicKey.isValidSignature(signature, for: message))

        let formattedPubKey = try strategy.formatPublicKey(publicKey: publicKey, encoding: .base58)
        let formattedSig = try strategy.formatSignature(signature: signature, encoding: .base58)

        #expect(formattedPubKey.keyType == "ed25519")
        #expect(formattedSig.keyType == "ed25519")
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
