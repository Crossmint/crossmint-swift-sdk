import Testing
@testable import CrossmintAuth

@Suite("AuthManager", .tags(.unit))
struct CrossmintAuthManagerTests {
    private let authManager = CrossmintAuthManager(
        authService: MockAuthService(),
        secureStorage: MockSecureStorage()
    )

    @Test func rejectsEmptyOtpCode() async {
        await #expect(throws: AuthManagerError.invalidInput("OTP code cannot be empty")) {
            _ = try await authManager.confirmEmailOtp(email: "user@example.com", code: "")
        }
    }

    @Test func rejectsWhitespaceOtpCode() async {
        await #expect(throws: AuthManagerError.invalidInput("OTP code cannot be empty")) {
            _ = try await authManager.confirmEmailOtp(email: "user@example.com", code: "   ")
        }
    }

    @Test func sendsOtpToValidEmail() async throws {
        try await authManager.sendEmailOtp(email: "user@example.com")
    }

    @Test func authenticatesWithValidOtpCode() async throws {
        try await authManager.sendEmailOtp(email: "user@example.com")
        _ = try await authManager.confirmEmailOtp(email: "user@example.com", code: "123456")
    }

    @Test func establishesSessionFromOneTimeSecret() async throws {
        let session = try await authManager.establishSession(oneTimeSecret: "test-secret")
        #expect(session.jwt == "test-jwt")
        #expect(session.email == "user@example.com")
    }
}
