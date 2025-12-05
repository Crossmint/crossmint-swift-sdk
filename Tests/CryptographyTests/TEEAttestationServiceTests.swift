import CryptoKit
@testable import Cryptography
@testable import CrossmintService
import Foundation
import Http
import XCTest

final class MockCrossmintService: CrossmintService, @unchecked Sendable {
    var responseToReturn: Any?
    var errorToThrow: Error?
    var lastEndpoint: Endpoint?

    var isProductionEnvironment: Bool = true

    func executeRequest<T, E>(
        _ endpoint: Endpoint,
        errorType: E.Type,
        _ transform: (NetworkError) -> E?
    ) async throws(E) -> T where T: Decodable, E: ServiceError {
        lastEndpoint = endpoint
        if let error = errorToThrow {
            if let typedError = error as? E {
                throw typedError
            }
            throw E.fromServiceError(.unknown)
        }
        guard let response = responseToReturn as? T else {
            throw E.fromServiceError(.invalidData("No response configured"))
        }
        return response
    }

    func executeRequest<E>(
        _ endpoint: Endpoint,
        errorType: E.Type,
        _ transform: (NetworkError) -> E?
    ) async throws(E) where E: ServiceError {
        lastEndpoint = endpoint
        if let error = errorToThrow {
            if let typedError = error as? E {
                throw typedError
            }
            throw E.fromServiceError(.unknown)
        }
    }

    func executeRequestForRawData<E>(
        _ endpoint: Endpoint,
        errorType: E.Type,
        _ transform: (NetworkError) -> E?
    ) async throws(E) -> Data where E: ServiceError {
        lastEndpoint = endpoint
        if let error = errorToThrow {
            if let typedError = error as? E {
                throw typedError
            }
            throw E.fromServiceError(.unknown)
        }
        return Data()
    }

    func getApiBaseURL() throws(CrossmintServiceError) -> URL {
        guard let url = URL(string: "https://staging.crossmint.com/api") else {
            throw .invalidURL
        }
        return url
    }
}

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

        let data = try XCTUnwrap(json.data(using: .utf8))
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

    func testTEEAttestationServiceInitialization() async throws {
        let verifier = MockTEEQuoteVerifier()
        let mockService = MockCrossmintService()
        let attestationService = TEEAttestationService(
            service: mockService,
            verifier: verifier
        )

        do {
            _ = try await attestationService.getAttestedPublicKey()
            XCTFail("Expected error for uninitialized service")
        } catch TEEAttestationError.notInitialized {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testTEEAttestationEndpointPath() {
        let endpoint = TEEAttestationEndpoint.getAttestation().endpoint
        XCTAssertEqual(endpoint.path, "/ncs/v1/attestation")
        XCTAssertEqual(endpoint.method, .get)
    }

    func testTEEAttestationErrorMessages() {
        XCTAssertEqual(
            TEEAttestationError.notInitialized.errorMessage,
            "TEE attestation service has not been initialized"
        )
        XCTAssertTrue(
            TEEAttestationError.attestationFetchFailed("test").errorMessage.contains("test")
        )
        XCTAssertTrue(
            TEEAttestationError.verificationFailed("reason").errorMessage.contains("reason")
        )
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
