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

    @Test(arguments: ["not-an-email", "", "user@", "@example.com"])
    func rejectsAnInvalidEmailBeforeCallingTheService(email: String) async {
        let authService = MockAuthService()
        let authManager = CrossmintAuthManager(authService: authService, secureStorage: MockSecureStorage())

        await #expect(throws: AuthManagerError.invalidEmail) {
            try await authManager.sendEmailOtp(email: email)
        }
        #expect(authService.validateEmailCallCount == 0)
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

    @Test func logoutSignsOutLocallyWhenTheServerLogoutFails() async throws {
        let authService = MockAuthService()
        authService.logoutError = .generic("offline")
        let storage = MockSecureStorage()
        let authManager = CrossmintAuthManager(authService: authService, secureStorage: storage)
        _ = try await authManager.establishSession(oneTimeSecret: "test-secret")

        await #expect(throws: AuthManagerError.self) {
            _ = try await authManager.logout()
        }

        #expect(await authManager.jwt == nil)
        #expect(try await relaunchStatus(authService: authService, storage: storage) == .nonAuthenticated)
    }

    @Test func logoutRevokesAndClearsAStoredSessionThatWasNotRestored() async throws {
        let authService = MockAuthService()
        let storage = MockSecureStorage(oneTimeSecret: "stored-secret")
        let authManager = CrossmintAuthManager(authService: authService, secureStorage: storage)

        _ = try await authManager.logout()

        #expect(authService.logoutLastRequest?.refresh == "stored-secret")
        #expect(try await relaunchStatus(authService: authService, storage: storage) == .nonAuthenticated)
    }

    @Test func resetSignsOut() async throws {
        let authService = MockAuthService()
        let storage = MockSecureStorage()
        let authManager = CrossmintAuthManager(authService: authService, secureStorage: storage)
        _ = try await authManager.establishSession(oneTimeSecret: "test-secret")

        _ = await authManager.reset()

        #expect(await authManager.jwt == nil)
        #expect(try await authManager.authenticationStatus == .nonAuthenticated)
        #expect(try await relaunchStatus(authService: authService, storage: storage) == .nonAuthenticated)
    }

    enum SignOut: CaseIterable {
        case logout, reset
    }

    @Test(arguments: SignOut.allCases)
    func signOutDuringSessionRestoreKeepsTheUserSignedOut(_ signOut: SignOut) async throws {
        let gate = SuspensionGate()
        let authService = MockAuthService()
        authService.refreshJWTGate = gate
        let storage = MockSecureStorage(oneTimeSecret: "stored-secret")
        let authManager = CrossmintAuthManager(authService: authService, secureStorage: storage)
        let restore = Task { try? await authManager.authenticationStatus }
        await gate.waitUntilArrived()

        switch signOut {
        case .logout: _ = try await authManager.logout()
        case .reset: _ = await authManager.reset()
        }
        gate.release()
        _ = await restore.value

        #expect(await authManager.jwt == nil)
        #expect(try await authManager.authenticationStatus == .nonAuthenticated)
        #expect(try await relaunchStatus(authService: authService, storage: storage) == .nonAuthenticated)
    }

    @Test(arguments: SignOut.allCases)
    func signOutDuringOtpConfirmationKeepsTheUserSignedOut(_ signOut: SignOut) async throws {
        let gate = SuspensionGate()
        let authService = MockAuthService()
        authService.validateTokenGate = gate
        let storage = MockSecureStorage()
        let authManager = CrossmintAuthManager(authService: authService, secureStorage: storage)
        try await authManager.sendEmailOtp(email: "user@example.com")
        let confirm = Task { try? await authManager.confirmEmailOtp(email: "user@example.com", code: "123456") }
        await gate.waitUntilArrived()

        switch signOut {
        case .logout: _ = try await authManager.logout()
        case .reset: _ = await authManager.reset()
        }
        gate.release()
        _ = await confirm.value

        #expect(await authManager.jwt == nil)
        #expect(try await relaunchStatus(authService: authService, storage: storage) == .nonAuthenticated)
    }

    @Test(arguments: SignOut.allCases)
    func signsInAgainAfterSignOut(_ signOut: SignOut) async throws {
        let authManager = CrossmintAuthManager(authService: MockAuthService(), secureStorage: MockSecureStorage())
        _ = try await authManager.establishSession(oneTimeSecret: "test-secret")
        switch signOut {
        case .logout: _ = try await authManager.logout()
        case .reset: _ = await authManager.reset()
        }

        _ = try await authManager.establishSession(oneTimeSecret: "test-secret")

        let status = try await authManager.authenticationStatus
        #expect(status == .authenticated(email: "user@example.com", jwt: "test-jwt", secret: "test-secret"))
    }

    @Test func jwtSetDuringSessionRestoreIsKept() async throws {
        let gate = SuspensionGate()
        let authService = MockAuthService()
        authService.refreshJWTGate = gate
        let authManager = CrossmintAuthManager(
            authService: authService,
            secureStorage: MockSecureStorage(oneTimeSecret: "stored-secret")
        )
        let restore = Task { try? await authManager.authenticationStatus }
        await gate.waitUntilArrived()

        await authManager.setJWT("injected-jwt")
        gate.release()
        _ = await restore.value

        #expect(await authManager.jwt == "injected-jwt")
        let status = try await authManager.authenticationStatus
        #expect(status == .authenticated(email: "", jwt: "injected-jwt", secret: ""))
    }

    @Test func logoutWhileASessionIsBeingSavedLeavesNothingToRestore() async throws {
        let gate = SuspensionGate()
        let authService = MockAuthService()
        let storage = MockSecureStorage()
        storage.storeJWTGate = gate
        let authManager = CrossmintAuthManager(authService: authService, secureStorage: storage)
        let signIn = Task { try? await authManager.establishSession(oneTimeSecret: "test-secret") }
        await gate.waitUntilArrived()

        _ = try await authManager.logout()
        gate.release()
        _ = await signIn.value

        #expect(await authManager.jwt == nil)
        #expect(try await relaunchStatus(authService: authService, storage: storage) == .nonAuthenticated)
    }

    private func relaunchStatus(
        authService: MockAuthService,
        storage: MockSecureStorage
    ) async throws -> AuthenticationStatus {
        try await CrossmintAuthManager(authService: authService, secureStorage: storage).authenticationStatus
    }
}
