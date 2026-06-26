import Testing
@testable import CrossmintService

struct CrossmintErrorTests {

    // MARK: - CrossmintServiceError

    @Test("CrossmintServiceError.unknown has expected code and message")
    func crossmintServiceErrorUnknown() {
        let error = CrossmintServiceError.unknown
        #expect(error.code == "SERVICE_ERROR")
        #expect(error.message == "Unknown error")
        #expect(error.recoverySuggestion == nil)
        #expect(error.underlyingError == nil)
    }

    @Test("CrossmintServiceError.invalidData carries detail in message")
    func crossmintServiceErrorInvalidData() {
        let error = CrossmintServiceError.invalidData("bad JSON")
        #expect(error.code == "INVALID_DATA")
        #expect(error.message == "Invalid data: bad JSON")
    }

    @Test("CrossmintServiceError.invalidApiKey has recovery suggestion")
    func crossmintServiceErrorInvalidApiKey() {
        let error = CrossmintServiceError.invalidApiKey("key123")
        #expect(error.code == "INVALID_API_KEY")
        #expect(error.recoverySuggestion == "Verify your API key in the Crossmint developer console.")
    }

    @Test("CrossmintServiceError.timeout has recovery suggestion")
    func crossmintServiceErrorTimeout() {
        let error = CrossmintServiceError.timeout
        #expect(error.code == "TIMEOUT")
        #expect(error.recoverySuggestion == "Check your network connection and retry the request.")
    }

    @Test("CrossmintServiceError.invalidURL has expected code")
    func crossmintServiceErrorInvalidURL() {
        let error = CrossmintServiceError.invalidURL
        #expect(error.code == "INVALID_URL")
        #expect(error.message == "Invalid URL")
    }

    // MARK: - description format

    @Test("CrossmintError description includes code and message")
    func descriptionIncludesCodeAndMessage() {
        let error = CrossmintServiceError.unknown
        let desc = error.description
        #expect(desc.contains("[SERVICE_ERROR]"))
        #expect(desc.contains("Unknown error"))
    }

    @Test("CrossmintError description includes recovery suggestion when present")
    func descriptionIncludesRecoverySuggestion() {
        let error = CrossmintServiceError.invalidApiKey("bad-key")
        let desc = error.description
        #expect(desc.contains("Recovery:"))
    }

    @Test("CrossmintError description omits recovery section when nil")
    func descriptionOmitsRecoveryWhenNil() {
        let error = CrossmintServiceError.unknown
        #expect(error.description == "[SERVICE_ERROR] Unknown error")
    }
}
