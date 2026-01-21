import Foundation
import Testing
@testable import Web

@Suite("NonCustodialSignResponse Tests")
struct NonCustodialSignResponseTests {

    @Test("Decode successful sign response with signature and publicKey")
    func testDecodeSuccessfulSignResponse() throws {
        let json = """
        {
            "event": "response:sign",
            "data": {
                "status": "success",
                "signature": {
                    "bytes": "286tF52C47NUK384m5uHmTpYxjMnXZHLTMjAJaChSKetckrYcAtnmBjybYMTXShN9H5yUV93XQEgJcsFrTyifQwE",
                    "encoding": "base58",
                    "keyType": "ed25519"
                },
                "publicKey": {
                    "bytes": "EX2jMfAdfUKSqh7415jsTzGE1KMepXPeqM4vXyCpVXGc",
                    "encoding": "base58",
                    "keyType": "ed25519"
                }
            }
        }
        """

        let data = Data(json.utf8)
        let decoder = JSONDecoder()

        let response = try decoder.decode(NonCustodialSignResponse.self, from: data)

        #expect(response.event == "response:sign")
        #expect(response.status == .success)
        #expect(response.errorMessage == nil)

        // Check signature
        let signature = try #require(response.signature)
        // swiftlint:disable:next line_length
        let expectedSigBytes = "286tF52C47NUK384m5uHmTpYxjMnXZHLTMjAJaChSKetckrYcAtnmBjybYMTXShN9H5yUV93XQEgJcsFrTyifQwE"
        #expect(signature.bytes == expectedSigBytes)
        #expect(signature.encoding == "base58")
        #expect(signature.keyType == "ed25519")

        // Check signature bytes convenience property
        #expect(response.signatureBytes == expectedSigBytes)

        // Check public key
        let publicKey = try #require(response.publicKey)
        #expect(publicKey.bytes == "EX2jMfAdfUKSqh7415jsTzGE1KMepXPeqM4vXyCpVXGc")
        #expect(publicKey.encoding == "base58")
        #expect(publicKey.keyType == "ed25519")
    }

    @Test("Decode error response")
    func testDecodeErrorResponse() throws {
        let json = """
        {"event":"response:sign","data":{"status":"error","error":"Signing failed"}}
        """

        let data = Data(json.utf8)
        let decoder = JSONDecoder()

        let response = try decoder.decode(NonCustodialSignResponse.self, from: data)

        #expect(response.event == "response:sign")
        #expect(response.status == .error)
        #expect(response.errorMessage == "Signing failed")
        #expect(response.signature == nil)
        #expect(response.publicKey == nil)
        #expect(response.signatureBytes == nil)
    }

    @Test("Decode response with missing optional fields")
    func testDecodeResponseWithMissingOptionalFields() throws {
        let json = """
        {"event":"response:sign","data":{"status":"success"}}
        """

        let data = Data(json.utf8)
        let decoder = JSONDecoder()

        let response = try decoder.decode(NonCustodialSignResponse.self, from: data)

        #expect(response.event == "response:sign")
        #expect(response.status == .success)
        #expect(response.signature == nil)
        #expect(response.publicKey == nil)
        #expect(response.errorMessage == nil)
        #expect(response.signatureBytes == nil)
    }

    @Test("Fail to decode response with missing status field")
    func testDecodeFailsWithMissingStatus() throws {
        let json = """
        {"event":"response:sign","data":{"signature":{"bytes":"test","encoding":"base58","keyType":"ed25519"}}}
        """

        let data = Data(json.utf8)
        let decoder = JSONDecoder()

        #expect(throws: DecodingError.self) {
            _ = try decoder.decode(NonCustodialSignResponse.self, from: data)
        }
    }

    @Test("Fail to decode response with invalid signature structure")
    func testDecodeFailsWithInvalidSignatureStructure() throws {
        let json = """
        {"event":"response:sign","data":{"status":"success","signature":"invalid_string_instead_of_object"}}
        """

        let data = Data(json.utf8)
        let decoder = JSONDecoder()

        #expect(throws: DecodingError.self) {
            _ = try decoder.decode(NonCustodialSignResponse.self, from: data)
        }
    }

    @Test("Message type constant is correct")
    func testMessageTypeConstant() {
        #expect(NonCustodialSignResponse.messageType == "response:sign")
    }

    @Test("Decode response with different key types")
    func testDecodeResponseWithDifferentKeyTypes() throws {
        let json = """
        {
            "event": "response:sign",
            "data": {
                "status": "success",
                "signature": {
                    "bytes": "0x1234567890abcdef",
                    "encoding": "hex",
                    "keyType": "secp256k1"
                },
                "publicKey": {
                    "bytes": "0xabcdef1234567890",
                    "encoding": "hex",
                    "keyType": "secp256k1"
                }
            }
        }
        """

        let data = Data(json.utf8)
        let decoder = JSONDecoder()

        let response = try decoder.decode(NonCustodialSignResponse.self, from: data)

        #expect(response.event == "response:sign")
        #expect(response.status == .success)

        let signature = try #require(response.signature)
        #expect(signature.bytes == "0x1234567890abcdef")
        #expect(signature.encoding == "hex")
        #expect(signature.keyType == "secp256k1")

        let publicKey = try #require(response.publicKey)
        #expect(publicKey.bytes == "0xabcdef1234567890")
        #expect(publicKey.encoding == "hex")
        #expect(publicKey.keyType == "secp256k1")
    }
}
