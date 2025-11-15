import Foundation
import Http
import Testing

@testable import CrossmintService

struct RequestEncodingUtilityTest {

    struct TestRequest: Encodable {
        let name: String
        let value: Int
    }

    struct InvalidRequest: Encodable {
        let date: Date = Date(timeIntervalSince1970: 0)

        func encode(to encoder: Encoder) throws {
            throw EncodingError.invalidValue(
                date,
                EncodingError.Context(
                    codingPath: [],
                    debugDescription: "Test encoding failure"
                )
            )
        }
    }

    enum MockServiceError: ServiceError {
        case serviceError(CrossmintServiceError)
        case customError(String)

        static func fromServiceError(_ error: CrossmintServiceError) -> MockServiceError {
            .serviceError(error)
        }

        static func fromNetworkError(_ error: NetworkError) -> MockServiceError {
            .customError(error.localizedDescription)
        }

        var errorMessage: String {
            switch self {
            case .serviceError(let error):
                return error.errorMessage
            case .customError(let message):
                return message
            }
        }
    }

    enum AnotherMockServiceError: ServiceError {
        case wrapped(CrossmintServiceError)
        case other(String)

        static func fromServiceError(_ error: CrossmintServiceError) -> AnotherMockServiceError {
            .wrapped(error)
        }

        static func fromNetworkError(_ error: NetworkError) -> AnotherMockServiceError {
            .other(error.localizedDescription)
        }

        var errorMessage: String {
            switch self {
            case .wrapped(let error):
                return "Wrapped: \(error.errorMessage)"
            case .other(let message):
                return "Other: \(message)"
            }
        }
    }

    struct MockSuccessJSONCoder: JSONCoder {
        let expectedData: Data

        init(expectedData: Data = Data("test".utf8)) {
            self.expectedData = expectedData
        }

        func encode<T>(_ instance: T) throws(CrossmintServiceError) -> Data where T: Encodable {
            return expectedData
        }

        func decode<T>(_ type: T.Type, from data: Data) throws(CrossmintServiceError) -> T where T: Decodable {
            throw .invalidData("Not implemented for tests")
        }
    }

    struct MockFailingJSONCoder: JSONCoder {
        let errorToThrow: CrossmintServiceError

        init(errorToThrow: CrossmintServiceError = .invalidData("Mock encoding error")) {
            self.errorToThrow = errorToThrow
        }

        func encode<T>(_ instance: T) throws(CrossmintServiceError) -> Data where T: Encodable {
            throw errorToThrow
        }

        func decode<T>(_ type: T.Type, from data: Data) throws(CrossmintServiceError) -> T where T: Decodable {
            throw .invalidData("Not implemented for tests")
        }
    }

    @Test("Successfully encodes request with mock service error")
    func successfullyEncodesRequestWithMockServiceError() throws {
        let expectedData = Data("test_data".utf8)
        let mockCoder = MockSuccessJSONCoder(expectedData: expectedData)
        let testRequest = TestRequest(name: "test", value: 42)

        let result = try RequestEncodingUtility.encodeRequest(
            testRequest,
            using: mockCoder,
            errorType: MockServiceError.self
        )

        #expect(result == expectedData)
    }

    @Test("Successfully encodes request with another mock service error")
    func successfullyEncodesRequestWithAnotherMockServiceError() throws {
        let expectedData = Data("another_test_data".utf8)
        let mockCoder = MockSuccessJSONCoder(expectedData: expectedData)
        let testRequest = TestRequest(name: "another", value: 123)

        let result = try RequestEncodingUtility.encodeRequest(
            testRequest,
            using: mockCoder,
            errorType: AnotherMockServiceError.self
        )

        #expect(result == expectedData)
    }

    @Test("Successfully encodes request with real JSONCoder")
    func successfullyEncodesRequestWithRealJSONCoder() throws {
        let realCoder = DefaultJSONCoder()
        let testRequest = TestRequest(name: "real_test", value: 999)

        let result = try RequestEncodingUtility.encodeRequest(
            testRequest,
            using: realCoder,
            errorType: MockServiceError.self
        )

        // Verify we got valid JSON data
        #expect(result.count > 0)

        // Verify it's valid JSON by decoding
        let json = try JSONSerialization.jsonObject(with: result) as? [String: Any]
        #expect(json?["name"] as? String == "real_test")
        #expect(json?["value"] as? Int == 999)
    }

    @Test("Handles CrossmintServiceError.invalidData")
    func handlesCrossmintServiceErrorInvalidData() {
        let mockCoder = MockFailingJSONCoder(errorToThrow: .invalidData("Invalid data test"))
        let testRequest = TestRequest(name: "test", value: 42)

        #expect {
            try RequestEncodingUtility.encodeRequest(
                testRequest,
                using: mockCoder,
                errorType: MockServiceError.self
            )
        } throws: { error in
            guard case .serviceError(let serviceError) = error as? MockServiceError,
                  case .invalidData(let message) = serviceError else {
                return false
            }
            return message == "Invalid data test"
        }
    }

    @Test("Handles CrossmintServiceError.unknown")
    func handlesCrossmintServiceErrorUnknown() {
        let mockCoder = MockFailingJSONCoder(errorToThrow: .unknown)
        let testRequest = TestRequest(name: "test", value: 42)

        #expect {
            try RequestEncodingUtility.encodeRequest(
                testRequest,
                using: mockCoder,
                errorType: MockServiceError.self
            )
        } throws: { error in
            guard case .serviceError(let serviceError) = error as? MockServiceError,
                  case .unknown = serviceError else {
                return false
            }
            return true
        }
    }

    @Test("Handles CrossmintServiceError.invalidApiKey")
    func handlesCrossmintServiceErrorInvalidApiKey() {
        let mockCoder = MockFailingJSONCoder(errorToThrow: .invalidApiKey("Invalid API key test"))
        let testRequest = TestRequest(name: "test", value: 42)

        #expect {
            try RequestEncodingUtility.encodeRequest(
                testRequest,
                using: mockCoder,
                errorType: AnotherMockServiceError.self
            )
        } throws: { error in
            guard case .wrapped(let serviceError) = error as? AnotherMockServiceError,
                  case .invalidApiKey(let message) = serviceError else {
                return false
            }
            return message == "Invalid API key test"
        }
    }

    @Test("Handles CrossmintServiceError.timeout")
    func handlesCrossmintServiceErrorTimeout() {
        let mockCoder = MockFailingJSONCoder(errorToThrow: .timeout)
        let testRequest = TestRequest(name: "test", value: 42)

        #expect {
            try RequestEncodingUtility.encodeRequest(
                testRequest,
                using: mockCoder,
                errorType: MockServiceError.self
            )
        } throws: { error in
            guard case .serviceError(let serviceError) = error as? MockServiceError,
                  case .timeout = serviceError else {
                return false
            }
            return true
        }
    }

    @Test("Handles CrossmintServiceError.invalidURL")
    func handlesCrossmintServiceErrorInvalidURL() {
        let mockCoder = MockFailingJSONCoder(errorToThrow: .invalidURL)
        let testRequest = TestRequest(name: "test", value: 42)

        #expect {
            try RequestEncodingUtility.encodeRequest(
                testRequest,
                using: mockCoder,
                errorType: AnotherMockServiceError.self
            )
        } throws: { error in
            guard case .wrapped(let serviceError) = error as? AnotherMockServiceError,
                  case .invalidURL = serviceError else {
                return false
            }
            return true
        }
    }

    @Test("Handles encoding errors from Encodable objects")
    func handlesEncodingErrorsFromEncodableObjects() throws {
        let realCoder = DefaultJSONCoder()
        let invalidRequest = InvalidRequest()

        #expect {
            try RequestEncodingUtility.encodeRequest(
                invalidRequest,
                using: realCoder,
                errorType: MockServiceError.self
            )
        } throws: { error in
            guard case .serviceError(let serviceError) = error as? MockServiceError,
                  case .invalidData(let message) = serviceError else {
                return false
            }
            return message.contains("Test encoding failure")
        }
    }

    @Test("Works with different ServiceError types")
    func worksWithDifferentServiceErrorTypes() {
        let expectedData = Data("type_test".utf8)
        let mockCoder = MockSuccessJSONCoder(expectedData: expectedData)
        let testRequest = TestRequest(name: "type_test", value: 1)

        // swiftlint:disable:next force_try
        let result1 = try! RequestEncodingUtility.encodeRequest(
            testRequest,
            using: mockCoder,
            errorType: MockServiceError.self
        )
        #expect(result1 == expectedData)

        // swiftlint:disable:next force_try
        let result2 = try! RequestEncodingUtility.encodeRequest(
            testRequest,
            using: mockCoder,
            errorType: AnotherMockServiceError.self
        )
        #expect(result2 == expectedData)
    }

    @Test("Error type mapping works correctly for different ServiceError implementations")
    func errorTypeMappingWorksCorrectlyForDifferentServiceErrorImplementations() {
        let mockCoder = MockFailingJSONCoder(errorToThrow: .invalidData("Mapping test"))
        let testRequest = TestRequest(name: "test", value: 42)

        #expect {
            try RequestEncodingUtility.encodeRequest(
                testRequest,
                using: mockCoder,
                errorType: MockServiceError.self
            )
        } throws: { error in
            if case .serviceError(let serviceError) = error as? MockServiceError {
                return serviceError.errorMessage == "Invalid data: Mapping test"
            }
            return false
        }

        #expect {
            try RequestEncodingUtility.encodeRequest(
                testRequest,
                using: mockCoder,
                errorType: AnotherMockServiceError.self
            )
        } throws: { error in
            if case .wrapped(let serviceError) = error as? AnotherMockServiceError {
                return serviceError.errorMessage == "Invalid data: Mapping test"
            }
            return false
        }
    }

    @Test("Handles empty data encoding")
    func handlesEmptyDataEncoding() throws {
        let emptyData = Data()
        let mockCoder = MockSuccessJSONCoder(expectedData: emptyData)
        let testRequest = TestRequest(name: "", value: 0)

        let result = try RequestEncodingUtility.encodeRequest(
            testRequest,
            using: mockCoder,
            errorType: MockServiceError.self
        )

        #expect(result == emptyData)
    }

    @Test("JSONCoder extension encodeForRequest works correctly")
    func jsonCoderExtensionEncodeForRequestWorksCorrectly() throws {
        let expectedData = Data("extension_test".utf8)
        let mockCoder = MockSuccessJSONCoder(expectedData: expectedData)
        let testRequest = TestRequest(name: "extension", value: 456)

        let result = try mockCoder.encodeRequest(
            testRequest,
            errorType: MockServiceError.self
        )

        #expect(result == expectedData)
    }

    @Test("JSONCoder extension handles errors correctly")
    func jsonCoderExtensionHandlesErrorsCorrectly() {
        let mockCoder = MockFailingJSONCoder(errorToThrow: .invalidData("Extension error test"))
        let testRequest = TestRequest(name: "test", value: 42)

        #expect {
            try mockCoder.encodeRequest(
                testRequest,
                errorType: MockServiceError.self
            )
        } throws: { error in
            guard case .serviceError(let serviceError) = error as? MockServiceError,
                  case .invalidData(let message) = serviceError else {
                return false
            }
            return message == "Extension error test"
        }
    }

    @Test("JSONCoder extension provides same results as RequestEncodingUtility")
    func jsonCoderExtensionProvidesSameResultsAsRequestEncodingUtility() throws {
        let expectedData = Data("consistency_test".utf8)
        let mockCoder = MockSuccessJSONCoder(expectedData: expectedData)
        let testRequest = TestRequest(name: "consistency", value: 789)

        // Test with RequestEncodingUtility
        let utilityResult = try RequestEncodingUtility.encodeRequest(
            testRequest,
            using: mockCoder,
            errorType: MockServiceError.self
        )

        // Test with JSONCoder extension
        let extensionResult = try mockCoder.encodeRequest(
            testRequest,
            errorType: MockServiceError.self
        )

        #expect(utilityResult == extensionResult)
        #expect(utilityResult == expectedData)
    }

    @Test("JSONCoder extension works with real DefaultJSONCoder")
    func jsonCoderExtensionWorksWithRealDefaultJSONCoder() throws {
        let realCoder = DefaultJSONCoder()
        let testRequest = TestRequest(name: "real_extension_test", value: 321)

        let result = try realCoder.encodeRequest(
            testRequest,
            errorType: MockServiceError.self
        )

        #expect(result.count > 0)

        // Verify it's valid JSON
        let json = try JSONSerialization.jsonObject(with: result) as? [String: Any]
        #expect(json?["name"] as? String == "real_extension_test")
        #expect(json?["value"] as? Int == 321)
    }
}
