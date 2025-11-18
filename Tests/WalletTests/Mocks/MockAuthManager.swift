import Foundation
import Auth
@testable import Wallet

actor MockAuthManager: AuthManager {
    private var _jwt: String?
    private var _email: String?
    private var _authenticationStatus: AuthenticationStatus = .nonAuthenticated
    private var _shouldThrowAuthError = false
    private var _otpAuthenticationResult: OTPAuthenticationStatus = .authenticationStatus(.nonAuthenticated)

    var jwt: String? {
        get async { _jwt }
    }

    var email: String? {
        get async { _email }
    }

    var authenticationStatus: AuthenticationStatus {
        get async throws(AuthError) {
            if _shouldThrowAuthError {
                throw AuthError.signInRequired
            }
            return _authenticationStatus
        }
    }

    func setJWT(_ jwt: String) async {
        _jwt = jwt
    }

    func setEmail(_ email: String?) {
        _email = email
    }

    func setAuthenticationStatus(_ status: AuthenticationStatus) {
        _authenticationStatus = status
    }

    func setShouldThrowAuthError(_ shouldThrow: Bool) {
        _shouldThrowAuthError = shouldThrow
    }

    func setOTPAuthenticationResult(_ result: OTPAuthenticationStatus) {
        _otpAuthenticationResult = result
    }

    func otpAuthentication(
        email: String,
        code: String?,
        forceRefresh: Bool
    ) async throws(AuthManagerError) -> OTPAuthenticationStatus {
        _email = email
        if case .authenticated(_, let authJWT, _) = _authenticationStatus {
            _jwt = authJWT
        }
        return _otpAuthenticationResult
    }

    #if DEBUG
    func oneTimeSecretAuthentication(
        oneTimeSecret: String
    ) async throws(AuthManagerError) -> OTPAuthenticationStatus {
        return _otpAuthenticationResult
    }
    #endif

    func logout() async throws(AuthManagerError) -> OTPAuthenticationStatus {
        _jwt = nil
        _email = nil
        _authenticationStatus = .nonAuthenticated
        return .authenticationStatus(.nonAuthenticated)
    }

    func reset() async -> OTPAuthenticationStatus {
        _jwt = nil
        _email = nil
        _authenticationStatus = .nonAuthenticated
        return .authenticationStatus(.nonAuthenticated)
    }
}
