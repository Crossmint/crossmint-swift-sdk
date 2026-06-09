//
//  AuthClient.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 6/1/26.
//

public protocol AuthClient: Sendable {
    func sendOTP(to email: String) async throws(AuthError) -> OTPRequest
    func verifyOTP(code: String, requestId: String) async throws(AuthError) -> AuthSession
    func logout() async
}
