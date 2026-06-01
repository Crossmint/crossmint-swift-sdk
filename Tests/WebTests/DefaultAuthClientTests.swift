//
//  DefaultAuthClientTests.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 6/1/26.
//

import Testing
@testable import CrossmintAuth

@Suite("AuthClient", .tags(.unit))
struct DefaultAuthClientTests {

    private func makeClient() -> DefaultAuthClient {
        let authService = MockAuthService()
        let authManager = CrossmintAuthManager(authService: authService, secureStorage: MockSecureStorage())
        return DefaultAuthClient(authService: authService, authManager: authManager)
    }

    @Test func sendsOTPAndReturnsRequestId() async throws {
        let client = makeClient()
        let request = try await client.sendOTP(to: "user@example.com")
        #expect(request.requestId == "test-email-id")
    }

    @Test func verifiesOTPWithValidCodeAndReturnsSession() async throws {
        let client = makeClient()
        let request = try await client.sendOTP(to: "user@example.com")
        let session = try await client.verifyOTP(code: "123456", requestId: request.requestId)
        #expect(session.jwt == "test-jwt")
        #expect(session.user.email == "user@example.com")
    }

    @Test func verifiesOTPWithUnknownRequestIdThrows() async {
        let client = makeClient()
        await #expect(throws: AuthError.self) {
            _ = try await client.verifyOTP(code: "123456", requestId: "unknown-id")
        }
    }

    @Test func logoutCompletesCleanly() async {
        let client = makeClient()
        await client.logout()
    }
}
