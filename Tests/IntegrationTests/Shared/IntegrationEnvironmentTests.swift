import CrossmintService
import Testing

@Suite("Integration environment")
struct IntegrationEnvironmentTests {
    @Test(arguments: [[:], ["PREVIEW_CK_KEY": ""]])
    func rejectsAMissingKey(environment: [String: String]) {
        #expect {
            try IntegrationEnvironment.clientApiKey(from: environment)
        } throws: { error in
            (error as? IntegrationSetupError)?.message.contains("is not set") == true
        }
    }

    @Test func rejectsAServerKey() {
        #expect {
            try IntegrationEnvironment.clientApiKey(from: ["PREVIEW_CK_KEY": "sk_staging_abc"])
        } throws: { error in
            (error as? IntegrationSetupError)?.message.contains("must be a client key") == true
        }
    }

    @Test func rejectsAMalformedKey() {
        #expect(throws: ApiKey.Error.self) {
            try IntegrationEnvironment.clientApiKey(from: ["PREVIEW_CK_KEY": "ck_"])
        }
    }

    @Test func acceptsAClientKey() throws {
        let apiKey = try IntegrationEnvironment.clientApiKey(from: ["PREVIEW_CK_KEY": "ck_staging_abc"])
        #expect(apiKey.type == .client)
        #expect(apiKey.environment == .staging)
    }
}
