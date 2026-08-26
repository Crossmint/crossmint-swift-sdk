import Logger
import CrossmintService
import SecureStorage
import Utils

/// Built-in ``AuthManager`` that authenticates users via email OTP.
///
/// ## OTP flow
/// ```swift
/// let auth = CrossmintSDK.shared.authManager
///
/// try await auth.sendEmailOtp(email: "user@example.com")
/// // ... user enters the code from their inbox ...
/// let status = try await auth.confirmEmailOtp(email: "user@example.com", code: userInput)
/// if status.isAuthenticated {
///     print("Signed in as", status.email ?? "")
/// }
/// ```
///
/// The JWT is refreshed automatically before expiry; no app-level polling is required.
public actor CrossmintAuthManager: AuthManager {
    enum Errors: Error {
        case noBundleIdFound
    }

    private let authService: AuthService
    private let secureStorage: SecureStorage
    private var otpAuthenticationStatus: OTPAuthenticationStatus = .authenticationStatus(.nonAuthenticated)
    private var _authenticationStatus: AuthenticationStatus?
    private var jwtRefreshTimer: Timer?

    public var jwt: String? {
        guard case let .authenticationStatus(.authenticated(_, jwt, _)) = otpAuthenticationStatus else {
            return nil
        }
        return jwt
    }

    public var email: String? {
        guard case let .authenticationStatus(.authenticated(email, _, _)) = otpAuthenticationStatus else {
            return nil
        }
        return email
    }

    public var authenticationStatus: AuthenticationStatus {
        get async throws(AuthError) {
            guard let authenticationStatus = _authenticationStatus else {
                let secret = await getOneTimeSecret()
                return try await performJWTRefresh(with: secret)
            }
            return authenticationStatus
        }
    }

    public init(
        authService: AuthService,
        secureStorage: SecureStorage
    ) {
        self.authService = authService
        self.secureStorage = secureStorage
    }

    public init(apiKey apiKeyString: String) throws {
        let apiKey = try ApiKey(key: apiKeyString)
        guard let bundleId = Bundle.main.bundleIdentifier else {
            throw Errors.noBundleIdFound
        }

        let secureStorage = KeychainSecureStorage(bundleId: bundleId)
        let crossmintService = DefaultCrossmintService(apiKey: apiKey, appIdentifier: bundleId)
        self.init(
            authService: DefaultAuthService(crossmintService: crossmintService),
            secureStorage: secureStorage
        )
    }

#if DEBUG
    public func oneTimeSecretAuthentication(
        oneTimeSecret: String
    ) async throws(AuthManagerError) -> OTPAuthenticationStatus {
        do {
            try await refreshJWT(oneTimeSecret)
            return otpAuthenticationStatus
        } catch {
            throw AuthManagerError.serviceError(error.localizedDescription)
        }
    }
#endif

    /// Sends a one-time password to the given email address. Call ``confirmEmailOtp(email:code:)`` next.
    public func sendEmailOtp(email: String) async throws(AuthManagerError) {
        let normalizedEmail = normalizeEmail(email)
        guard isValidEmail(normalizedEmail) else {
            throw AuthManagerError.invalidEmail
        }
        do {
            let newStatus = try await startEmailValidation(email: normalizedEmail)
            jwtRefreshTimer?.invalidate()
            otpAuthenticationStatus = newStatus
        } catch {
            throw AuthManagerError.serviceError(error.message)
        }
    }

    /// Validates the OTP code and, on success, establishes an authenticated session.
    ///
    /// Must be called after ``sendEmailOtp(email:)`` with the same email address.
    /// Throws ``AuthManagerError/noPendingOTP`` if no email has been sent yet.
    public func confirmEmailOtp(email: String, code: String) async throws(AuthManagerError) -> OTPAuthenticationStatus {
        if code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw AuthManagerError.invalidInput("OTP code cannot be empty")
        }
        let normalizedEmail = normalizeEmail(email)
        guard case let .emailSent(verifiedEmail, emailId) = otpAuthenticationStatus,
              verifiedEmail == normalizedEmail else {
            throw AuthManagerError.noPendingOTP
        }
        do {
            try await refreshJWT(
                try await authService.validateToken(
                    ValidateTokenRequest(email: verifiedEmail, token: code, emailID: emailId)
                ).oneTimeSecret
            )
            return otpAuthenticationStatus
        } catch {
            throw AuthManagerError.serviceError(error.message)
        }
    }

    /// Invalidates the server-side refresh token and clears the local session.
    ///
    /// Has no effect if the user is not currently authenticated.
    public func logout() async throws(AuthManagerError) -> OTPAuthenticationStatus {
        guard case let .authenticationStatus(.authenticated(_, _, secret)) = otpAuthenticationStatus else {
            Logger.auth.debug("User is not authenticated. Nothing to logout")
            return otpAuthenticationStatus
        }

        do {
            if !secret.isEmpty {
                try await authService.logout(LogoutRequest(refresh: secret))
            }
            secureStorage.clear()
            otpAuthenticationStatus = .authenticationStatus(.nonAuthenticated)
            _authenticationStatus = .nonAuthenticated
            return otpAuthenticationStatus
        } catch {
            Logger.auth.error("Error while logging out: \(error.localizedDescription)")
            throw AuthManagerError.serviceError(error.message)
        }
    }

    /// Clears the local session state without contacting the server.
    ///
    /// Use this when the server session is already gone (e.g. the refresh token expired or was
    /// revoked externally) and you just need to reset local state. Prefer ``logout()`` when the
    /// session is still valid and you want to revoke the server-side token as well.
    public func reset() async -> OTPAuthenticationStatus {
        otpAuthenticationStatus = .authenticationStatus(.nonAuthenticated)
        return otpAuthenticationStatus
    }

    public func setJWT(_ jwt: String) async {
        jwtRefreshTimer?.invalidate()
        let authStatus = AuthenticationStatus.authenticated(
            email: "",
            jwt: jwt,
            secret: ""
        )
        otpAuthenticationStatus = .authenticationStatus(authStatus)
        _authenticationStatus = authStatus
    }

    internal func establishSession(oneTimeSecret: String) async throws(AuthError) -> (jwt: String, email: String) {
        let authStatus = try await refreshJWT(oneTimeSecret)
        guard case let .authenticated(email, jwt, _) = authStatus else {
            throw AuthError.generic("Session could not be established")
        }
        return (jwt: jwt, email: email)
    }

    private func startEmailValidation(email: String) async throws(AuthError) -> OTPAuthenticationStatus {
        return .emailSent(
            email: email,
            emailId: try await authService.validateEmail(.init(email: email)).emailId
        )
    }

    @discardableResult
    private func refreshJWT(
        _ oneTimeSecret: String
    ) async throws(AuthError) -> AuthenticationStatus {
        let jwtResponse = try await authService.refreshJWT(RefreshJWTRequest(refresh: oneTimeSecret))

        let jwtExpirationInSeconds = Date().distance(to: jwtResponse.refresh.expiresAt)
        let nextRefreshInSeconds = jwtExpirationInSeconds * 0.9
        jwtRefreshTimer?.invalidate()
        // swiftlint:disable:next line_length
        Logger.auth.debug("JWT will expire in \(jwtExpirationInSeconds) seconds. Schuduling a refresh 10% earlier (\(nextRefreshInSeconds))")
        jwtRefreshTimer = Timer.scheduledTimer(
            withTimeInterval: nextRefreshInSeconds,
            repeats: false
        ) { [weak self] _ in
            Task {
                // swiftlint:disable:next line_length
                guard case let .authenticationStatus(.authenticated(_, _, oneTimeSecret)) = await self?.otpAuthenticationStatus else {
                    throw AuthError.generic("User is not authenticated")
                }
                _ = try await self?.refreshJWT(oneTimeSecret)
            }
        }

        let authStatus = AuthenticationStatus.authenticated(
            email: jwtResponse.user.email,
            jwt: jwtResponse.jwt,
            secret: jwtResponse.refresh.secret
        )
        otpAuthenticationStatus = .authenticationStatus(authStatus)

        await store(authStatus)
        return authStatus
    }

    private func store(_ authenticationStatus: AuthenticationStatus) async {
        switch authenticationStatus {
        case .nonAuthenticated:
            secureStorage.clear()
        case .authenticated(let email, let jwt, let secret):
            try? await secureStorage.storeJWT(jwt)
            try? await secureStorage.storeOneTimeSecret(secret)
            try? await secureStorage.storeEmail(email)
        case .authenticating:
            break
        }
    }

    private func getOneTimeSecret() async -> String {
        do {
            return try await secureStorage.getOneTimeSecret() ?? ""
        } catch {
            let message = "Failed to read one-time secret from keychain, " +
                "treating as non-authenticated: \(error.localizedDescription)"
            Logger.auth.error(message)
            return ""
        }
    }

    private func performJWTRefresh(with oneTimeSecret: String) async throws(AuthError) -> AuthenticationStatus {
        guard !oneTimeSecret.isEmpty else {
            _authenticationStatus = .nonAuthenticated
            return .nonAuthenticated
        }

        _authenticationStatus = .authenticating
        do {
            let authStatus = try await refreshJWT(oneTimeSecret)
            _authenticationStatus = authStatus
            return authStatus
        } catch {
            _authenticationStatus = .nonAuthenticated
            throw AuthError.signInRequired
        }
    }
}
