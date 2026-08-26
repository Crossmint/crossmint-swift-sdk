//
//  SignerProvider.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 01/09/26.
//

public protocol SignerProvider: Sendable {
    @MainActor var signer: any Signer { get }
}
