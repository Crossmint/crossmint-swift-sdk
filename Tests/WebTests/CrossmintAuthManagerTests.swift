import Testing
@testable import CrossmintAuth
import SecureStorage

struct CrossmintAuthManagerTests {
    private let authManager = CrossmintAuthManager(
        authService: StubAuthService(),
        secureStorage: StubSecureStorage()
    )

    @Test("Throws invalidInput when OTP code is empty")
    func throwsOnEmptyCode() async {
        await #expect(throws: AuthManagerError.invalidInput("OTP code cannot be empty")) {
            _ = try await authManager.otpAuthentication(email: "user@example.com", code: "")
        }
    }

    @Test("Throws invalidInput when OTP code is whitespace only")
    func throwsOnWhitespaceCode() async {
        await #expect(throws: AuthManagerError.invalidInput("OTP code cannot be empty")) {
            _ = try await authManager.otpAuthentication(email: "user@example.com", code: "   ")
        }
    }

    @Test("Does not throw when OTP code is nil")
    func doesNotThrowOnNilCode() async throws {
        await #expect(throws: Never.self) {
            _ = try await authManager.otpAuthentication(email: "user@example.com", code: nil)
        }
    }

    @Test("Does not throw when OTP code is non-empty")
    func doesNotThrowOnNonEmptyCode() async throws {
        await #expect(throws: Never.self) {
            _ = try await authManager.otpAuthentication(email: "user@example.com", code: "123456")
        }
    }
}

// MARK: - Test Doubles

private struct StubAuthService: AuthService {
    func validateEmail(_ request: ValidateEmailRequest) async throws(AuthError) -> ValidateEmailResponse {
        ValidateEmailResponse(emailId: "test-email-id")
    }

    func validateToken(_ request: ValidateTokenRequest) async throws(AuthError) -> ValidateTokenResponse {
        ValidateTokenResponse(callbackUrl: "", oneTimeSecret: "test-secret")
    }

    func refreshJWT(_ request: RefreshJWTRequest) async throws(AuthError) -> RefreshJWTResponse {
        throw AuthError.generic("not implemented")
    }

    func logout(_ request: LogoutRequest) async throws(AuthError) {}
}

private struct StubSecureStorage: SecureStorage {
    func getOneTimeSecret() async throws(SecureStorageError) -> String? { nil }
    func storeOneTimeSecret(_ secret: String) async throws(SecureStorageError) {}
    func getJWT() async throws(SecureStorageError) -> String? { nil }
    func storeJWT(_ secret: String) async throws(SecureStorageError) {}
    func getEmail() async throws(SecureStorageError) -> String? { nil }
    func storeEmail(_ email: String) async throws(SecureStorageError) {}
    func clear() {}
}
