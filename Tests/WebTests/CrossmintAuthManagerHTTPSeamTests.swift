import Testing
import TestsUtils
@testable import CrossmintAuth

@Suite("AuthManager HTTP seam", .tags(.unit))
struct CrossmintAuthManagerHTTPSeamTests {
    @Test func sendsTheOtpRequestThroughTheInjectedClient() async throws {
        let router = HTTPFixtureRouter()
        router.respond(to: "POST", path: "/2024-09-26/session/sdk/auth/otps/send", json: #"{"emailId": "email-1"}"#)
        let authManager = try CrossmintAuthManager(apiKey: "ck_staging_test123", httpClient: router.client)

        try await authManager.sendEmailOtp(email: "user@example.com")

        #expect(router.requests.count == 1)
        #expect(router.lastRequest?.url?.host == "staging.crossmint.com")
    }
}
