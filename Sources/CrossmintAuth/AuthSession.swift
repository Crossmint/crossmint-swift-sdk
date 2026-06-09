//
//  AuthSession.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 6/1/26.
//

public struct AuthSession: Sendable {
    public let jwt: String
    public let user: AuthUser
}
