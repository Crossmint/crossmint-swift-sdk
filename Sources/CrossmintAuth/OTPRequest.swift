//
//  OTPRequest.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 6/1/26.
//

public struct OTPRequest: Sendable, Identifiable {
    public var id: String { requestId }
    public let requestId: String
}
