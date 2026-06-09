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
        makeClientWithService().0
    }

    private func makeClientWithService() -> (DefaultAuthClient, MockAuthService) {
        let authService = MockAuthService()
        let authManager = CrossmintAuthManager(authService: authService, secureStorage: MockSecureStorage())
        return (DefaultAuthClient(authService: authService, authManager: authManager), authService)
    }

    @Test func sendsOTPAndReturnsRequestId() async throws {
        let client = makeClient()
        let request = try await client.sendOTP(to: "user@example.com")
        #expect(request.requestId == "test-email-id")
    }

    @Test func normalizesEmailBeforeSending() async throws {
        let (client, authService) = makeClientWithService()
        _ = try await client.sendOTP(to: "  USER@EXAMPLE.COM  ")
        #expect(authService.validateEmailLastRequest?.email == "user@example.com")
    }

    @Test func rejectsInvalidEmail() async {
        let client = makeClient()
        await #expect(throws: AuthError.self) {
            _ = try await client.sendOTP(to: "not-an-email")
        }
    }

    @Test func verifiesOTPWithValidCodeAndReturnsSession() async throws {
        let client = makeClient()
        let request = try await client.sendOTP(to: "user@example.com")
        let session = try await client.verifyOTP(code: "123456", requestId: request.requestId)
        #expect(session.jwt == "test-jwt")
        #expect(session.user.email == "user@example.com")
    }

    @Test func verifiesOTPPassesCorrectRequestToService() async throws {
        let (client, authService) = makeClientWithService()
        let request = try await client.sendOTP(to: "user@example.com")
        _ = try await client.verifyOTP(code: "123456", requestId: request.requestId)
        #expect(authService.validateTokenLastRequest?.email == "user@example.com")
        #expect(authService.validateTokenLastRequest?.token == "123456")
        #expect(authService.validateTokenLastRequest?.emailID == request.requestId)
    }

    @Test func verifiesOTPEstablishesSessionWithCorrectOneTimeSecret() async throws {
        let (client, authService) = makeClientWithService()
        let request = try await client.sendOTP(to: "user@example.com")
        _ = try await client.verifyOTP(code: "123456", requestId: request.requestId)
        #expect(authService.refreshJWTLastRequest?.refresh == "test-secret")
    }

    @Test func rejectsUnknownRequestId() async {
        let client = makeClient()
        await #expect(throws: AuthError.self) {
            _ = try await client.verifyOTP(code: "123456", requestId: "unknown-id")
        }
    }

    @Test func rejectsDoubleVerifyOfSameOTP() async throws {
        let client = makeClient()
        let request = try await client.sendOTP(to: "user@example.com")
        _ = try await client.verifyOTP(code: "123456", requestId: request.requestId)
        await #expect(throws: AuthError.self) {
            _ = try await client.verifyOTP(code: "123456", requestId: request.requestId)
        }
    }

    @Test func logoutCompletesCleanly() async {
        let client = makeClient()
        await client.logout()
    }
}
