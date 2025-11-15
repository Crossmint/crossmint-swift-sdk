import Foundation
import Testing
@testable import Web

@Suite("GetStatusResponse Tests")
struct GetStatusResponseTests {

    @Test("Decode new device response with signerStatus")
    func testDecodeNewDeviceResponse() throws {
        let json = """
        {"event":"response:get-status","data":{"status":"success","signerStatus":"new-device"}}
        """

        let data = Data(json.utf8)
        let decoder = JSONDecoder()

        let response = try decoder.decode(GetStatusResponse.self, from: data)

        #expect(response.event == "response:get-status")
        switch response.data {
        case .basic(let basicResponseData):
            #expect(basicResponseData.status == .success)
            #expect(basicResponseData.signerStatus == .newDevice)
        default:
            Issue.record("Expected BasicResponseData type")
        }
    }

    @Test("Fail to decode response with missing status field")
    func testDecodeFailsWithMissingStatus() throws {
        let json = """
        {"event":"response:get-status","data":{"signerStatus":"new-device"}}
        """

        let data = Data(json.utf8)
        let decoder = JSONDecoder()

        #expect(throws: DecodingError.self) {
            _ = try decoder.decode(GetStatusResponse.self, from: data)
        }
    }

    @Test("Fail to decode response with empty data")
    func testDecodeFailsWithEmptyData() throws {
        let json = """
        {"event":"response:get-status","data":{}}
        """

        let data = Data(json.utf8)
        let decoder = JSONDecoder()

        #expect(throws: DecodingError.self) {
            _ = try decoder.decode(GetStatusResponse.self, from: data)
        }
    }

    @Test("Fail to decode response with invalid JSON")
    func testDecodeFailsWithInvalidJSON() throws {
        let json = """
        {"event":"response:get-status","data":
        """

        let data = Data(json.utf8)
        let decoder = JSONDecoder()

        #expect(throws: DecodingError.self) {
            _ = try decoder.decode(GetStatusResponse.self, from: data)
        }
    }

    @Test("Message type constant is correct")
    func testMessageTypeConstant() {
        #expect(GetStatusResponse.messageType == "response:get-status")
    }

    @Test("Decode error message")
    func testDecodeErrorMessage() throws {
        let json = """
        {"event":"response:get-status","data":{"status":"error","error":"An internal error occurred"}}
        """

        let data = Data(json.utf8)
        let decoder = JSONDecoder()

        let response = try decoder.decode(GetStatusResponse.self, from: data)

        #expect(response.event == "response:get-status")
        #expect(response.status == .error)
        switch response.data {
        case .basic(let basicResponseData):
            #expect(basicResponseData.error == "An internal error occurred")
        default:
            Issue.record("Expected BasicResponseData")
        }
    }

    @Test("Decode response with publicKeys")
    func testDecodePublicKeysResponse() throws {
        let json = """
        {
            "event": "response:get-status",
            "data": {
                "status": "success",
                "signerStatus": "ready",
                "publicKeys": {
                    "ed25519": {
                        "bytes": "base64EncodedEd25519PublicKey",
                        "encoding": "base64",
                        "keyType": "ed25519"
                    },
                    "secp256k1": {
                        "bytes": "hexEncodedSecp256k1PublicKey",
                        "encoding": "hex",
                        "keyType": "secp256k1"
                    }
                }
            }
        }
        """

        let data = Data(json.utf8)
        let decoder = JSONDecoder()

        let response = try decoder.decode(GetStatusResponse.self, from: data)

        #expect(response.event == "response:get-status")
        #expect(response.status == .success)
        #expect(response.signerStatus == .ready)

        switch response.data {
        case .withPublicKeys(let publicKeysResponseData):
            #expect(publicKeysResponseData.status == .success)
            #expect(publicKeysResponseData.signerStatus == .ready)

            let publicKeys = publicKeysResponseData.publicKeys
            #expect(publicKeys.ed25519.bytes == "base64EncodedEd25519PublicKey")
            #expect(publicKeys.ed25519.encoding == "base64")
            #expect(publicKeys.ed25519.keyType == "ed25519")

            #expect(publicKeys.secp256k1.bytes == "hexEncodedSecp256k1PublicKey")
            #expect(publicKeys.secp256k1.encoding == "hex")
            #expect(publicKeys.secp256k1.keyType == "secp256k1")
        default:
            Issue.record("Expected PublicKeysResponseData type")
        }
    }
}
