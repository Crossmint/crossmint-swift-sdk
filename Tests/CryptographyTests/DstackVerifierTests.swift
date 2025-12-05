@testable import Cryptography
import Foundation
import XCTest

final class DstackVerifierTests: XCTestCase {
    func testPhalaQuoteBodyDecoding() throws {
        let json = """
        {
            "reportdata": "0xabc123",
            "rtmr3": "0xdef456"
        }
        """

        let data = try XCTUnwrap(json.data(using: .utf8))
        let decoder = JSONDecoder()
        let body = try decoder.decode(PhalaQuoteBody.self, from: data)

        XCTAssertEqual(body.reportdata, "0xabc123")
        XCTAssertEqual(body.rtmr3, "0xdef456")
    }

    func testPhalaQuoteResponseDecoding() throws {
        let json = """
        {
            "success": true,
            "quote": {
                "body": {
                    "reportdata": "0xabc123",
                    "rtmr3": "0xdef456"
                }
            }
        }
        """

        let data = try XCTUnwrap(json.data(using: .utf8))
        let decoder = JSONDecoder()
        let response = try decoder.decode(PhalaQuoteResponse.self, from: data)

        XCTAssertTrue(response.success)
        XCTAssertEqual(response.quote.body.reportdata, "0xabc123")
        XCTAssertEqual(response.quote.body.rtmr3, "0xdef456")
    }

    func testPhalaQuoteResponseDecodingFailure() throws {
        let json = """
        {
            "success": false,
            "quote": {
                "body": {
                    "reportdata": "0xabc123",
                    "rtmr3": "0xdef456"
                }
            }
        }
        """

        let data = try XCTUnwrap(json.data(using: .utf8))
        let decoder = JSONDecoder()
        let response = try decoder.decode(PhalaQuoteResponse.self, from: data)

        XCTAssertFalse(response.success)
    }

    func testDstackVerifierErrorEquality() {
        XCTAssertEqual(
            DstackVerifierError.verificationFailed("test"),
            DstackVerifierError.verificationFailed("test")
        )
        XCTAssertNotEqual(
            DstackVerifierError.verificationFailed("test1"),
            DstackVerifierError.verificationFailed("test2")
        )
        XCTAssertEqual(
            DstackVerifierError.invalidResponse,
            DstackVerifierError.invalidResponse
        )
        XCTAssertEqual(
            DstackVerifierError.networkError("test"),
            DstackVerifierError.networkError("test")
        )
    }

    func testDstackVerifierInitialization() {
        let verifier = DstackVerifier()
        XCTAssertNotNil(verifier)
    }

    func testDstackVerifierCustomURL() throws {
        let customURL = try XCTUnwrap(URL(string: "https://custom.api.com/verify"))
        let verifier = DstackVerifier(phalaApiURL: customURL)
        XCTAssertNotNil(verifier)
    }

    func testTEEReportDataStruct() {
        let reportData = TEEReportData(reportData: "abc123", rtMr3: "def456")
        XCTAssertEqual(reportData.reportData, "abc123")
        XCTAssertEqual(reportData.rtMr3, "def456")
    }
}
