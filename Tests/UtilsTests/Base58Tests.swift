import Foundation
import Testing
@testable import Utils

@Suite("Base58 Tests")
struct Base58Tests {

    @Test("Decode valid address")
    func testBase58Decoding() throws {
        let address = "4Nd1mY4vj4ZHz5dSXZj7ymfMBLzRxrBE6wQpN6WsjTnf"
        let expectedHex = "321cfa62b561320538975f52be25b5ba1ce39cccaf11df1c3aabec9ee04abb90"

        let decoded = try Base58.decode(address)

        try #require(decoded.count == 32, "Decoded public key should be 32 bytes")

        let hex = decoded.map { String(format: "%02x", $0) }.joined()
        try #require(hex == expectedHex, "Public key hex did not match expected value")
    }

    @Test("Decode Base58 with leading ones (zeros)")
    func testLeadingOnesDecode() throws {
        let base58 = "11"
        let decoded = try Base58.decode(base58)
        let expected = Data(repeating: 0, count: 32)
        #expect(decoded == expected)
    }

    @Test("Decode invalid Base58 string")
    func testInvalidBase58Decode() throws {
        #expect(throws: Base58.Error.decodingError) {
            try Base58.decode("f0")
        }
    }

    @Test("Decode Base58 string too long for 32 bytes")
    func testTooLongBase58Decode() throws {
        let longString = String(repeating: "1", count: 45)
        #expect(throws: Base58.Error.invalidLength) {
            try Base58.decode(longString)
        }
    }

    @Test("Decode empty Base58 string")
    func testEmptyBase58Decode() throws {
        let base58 = ""
        let decoded = try Base58.decode(base58)
        #expect(decoded.isEmpty, "Empty string should decode to empty data")
    }

    @Test("Encode and decode roundtrip")
    func testEncodeDecode() throws {
        let original = "4Nd1mY4vj4ZHz5dSXZj7ymfMBLzRxrBE6wQpN6WsjTnf"
        let decoded = try Base58.decode(original)
        let encoded = try Base58.encode(decoded)

        #expect(encoded == original, "Encoded value should match original")

        let secondDecode = try Base58.decode(encoded)
        #expect(secondDecode == decoded, "Second decode should match first decode")
    }

    @Test("Encode from raw bytes")
    func testEncodeFromBytes() throws {
        // hex: 321cfa62b561320538975f52be25b5ba1ce39cccaf11df1c3aabec9ee04abb90
        let bytes: [UInt8] = [
            0x32, 0x1c, 0xfa, 0x62, 0xb5, 0x61, 0x32, 0x05,
            0x38, 0x97, 0x5f, 0x52, 0xbe, 0x25, 0xb5, 0xba,
            0x1c, 0xe3, 0x9c, 0xcc, 0xaf, 0x11, 0xdf, 0x1c,
            0x3a, 0xab, 0xec, 0x9e, 0xe0, 0x4a, 0xbb, 0x90
        ]
        let data = Data(bytes)
        let encoded = try Base58.encode(data)

        #expect(encoded == "4Nd1mY4vj4ZHz5dSXZj7ymfMBLzRxrBE6wQpN6WsjTnf", "Encoded value should match expected")
    }

    @Test("Encode with leading zeros")
    func testEncodeLeadingZeros() throws {
        // Data with leading zeros
        let data = Data([0x00, 0x00, 0x01, 0x02])
        let encoded = try Base58.encode(data)

        #expect(encoded.hasPrefix("11"), "Encoded value should have leading '1's for zeros")

        let decoded = try Base58.decode(encoded, padTo32: false)
        #expect(decoded == data, "Decoded value should match original with zeros")
    }

    @Test("Encode empty data")
    func testEncodeEmpty() throws {
        let data = Data()
        let encoded = try Base58.encode(data)

        #expect(encoded.isEmpty, "Empty data should encode to empty string")
    }

    @Test("Valid Solana address validation")
    func testValidSolanaAddress() {
        let validAddress = "4Nd1mY4vj4ZHz5dSXZj7ymfMBLzRxrBE6wQpN6WsjTnf"
        #expect(Base58.isValidSolanaAddress(validAddress), "Valid Solana address should pass validation")
    }

    @Test("Invalid Solana address validation - wrong characters")
    func testInvalidSolanaAddressChars() {
        let invalidAddress = "4Nd1mY4vj4ZHz5dSXZj7ymfMBLzRxrBE6wQpN6WsjTn0" // Contains '0' which isn't in Base58
        #expect(!Base58.isValidSolanaAddress(invalidAddress), "Address with invalid characters should fail validation")
    }

    @Test("Invalid Solana address validation - too short")
    func testInvalidSolanaAddressTooShort() {
        let tooShortAddress = "4Nd1"
        #expect(!Base58.isValidSolanaAddress(tooShortAddress), "Address that's too short should fail validation")
    }

    @Test("Invalid Solana address validation - too long")
    func testInvalidSolanaAddressTooLong() {
        let tooLongAddress = String(repeating: "1", count: 45)
        #expect(!Base58.isValidSolanaAddress(tooLongAddress), "Address that's too long should fail validation")
    }
}
