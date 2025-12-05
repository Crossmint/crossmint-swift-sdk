import CryptoKit
@testable import Cryptography
import Foundation
import XCTest

final class MockTEEQuoteVerifier: TEEQuoteVerifier, @unchecked Sendable {
    var shouldSucceed = true
    var reportDataToReturn = "test_report_data"
    var rtMr3ToReturn = "test_rt_mr3"

    func verifyTEEReportAndExtractTD(quote: String) async throws -> TEEReportData {
        if !shouldSucceed {
            throw DstackVerifierError.verificationFailed("Mock verification failed")
        }
        return TEEReportData(reportData: reportDataToReturn, rtMr3: rtMr3ToReturn)
    }
}

final class TEEAttestationServiceTests: XCTestCase {
    func testTEEReportDataCreation() {
        let reportData = TEEReportData(reportData: "abc123", rtMr3: "def456")
        XCTAssertEqual(reportData.reportData, "abc123")
        XCTAssertEqual(reportData.rtMr3, "def456")
    }

    func testAttestationResponseDecoding() throws {
        let json = """
        {
            "publicKey": "dGVzdF9wdWJsaWNfa2V5",
            "timestamp": 1234567890,
            "quote": "test_quote",
            "event_log": "test_event_log",
            "hash_algorithm": "sha512",
            "prefix": "app-data"
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let response = try decoder.decode(AttestationResponse.self, from: data)

        XCTAssertEqual(response.publicKey, "dGVzdF9wdWJsaWNfa2V5")
        XCTAssertEqual(response.timestamp, 1234567890)
        XCTAssertEqual(response.quote, "test_quote")
        XCTAssertEqual(response.eventLog, "test_event_log")
        XCTAssertEqual(response.hashAlgorithm, "sha512")
        XCTAssertEqual(response.prefix, "app-data")
    }

    func testMockVerifierSuccess() async throws {
        let verifier = MockTEEQuoteVerifier()
        verifier.reportDataToReturn = "expected_report_data"
        verifier.rtMr3ToReturn = "expected_rt_mr3"

        let result = try await verifier.verifyTEEReportAndExtractTD(quote: "test_quote")

        XCTAssertEqual(result.reportData, "expected_report_data")
        XCTAssertEqual(result.rtMr3, "expected_rt_mr3")
    }

    func testMockVerifierFailure() async {
        let verifier = MockTEEQuoteVerifier()
        verifier.shouldSucceed = false

        do {
            _ = try await verifier.verifyTEEReportAndExtractTD(quote: "test_quote")
            XCTFail("Expected verification to fail")
        } catch {
            XCTAssertTrue(error is DstackVerifierError)
        }
    }

    func testTEEAttestationServiceInitialization() async {
        let verifier = MockTEEQuoteVerifier()
        let service = TEEAttestationService(
            apiBaseURL: URL(string: "https://example.com")!,
            verifier: verifier
        )

        do {
            _ = try await service.getAttestedPublicKey()
            XCTFail("Expected error for uninitialized service")
        } catch TEEAttestationError.notInitialized {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testTEEAttestationErrorEquality() {
        XCTAssertEqual(TEEAttestationError.notInitialized, TEEAttestationError.notInitialized)
        XCTAssertEqual(
            TEEAttestationError.attestationFetchFailed("test"),
            TEEAttestationError.attestationFetchFailed("test")
        )
        XCTAssertNotEqual(
            TEEAttestationError.attestationFetchFailed("test1"),
            TEEAttestationError.attestationFetchFailed("test2")
        )
        XCTAssertEqual(TEEAttestationError.invalidPublicKey, TEEAttestationError.invalidPublicKey)
        XCTAssertEqual(
            TEEAttestationError.publicKeyImportFailed,
            TEEAttestationError.publicKeyImportFailed
        )
        XCTAssertEqual(
            TEEAttestationError.attestationExpired,
            TEEAttestationError.attestationExpired
        )
    }
}
