//
//  OTPRequest.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 6/1/26.
//

/// Carries the identifier needed to verify an OTP sent by ``AuthClient/sendOTP(to:)``.
public struct OTPRequest: Sendable, Identifiable {
    public var id: String { requestId }
    /// Pass this to ``AuthClient/verifyOTP(code:requestId:)`` along with the user's code.
    public let requestId: String
}
