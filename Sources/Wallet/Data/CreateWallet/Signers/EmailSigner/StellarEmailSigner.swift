//
//  StellarEmailSigner.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 12/22/25.
//

import CrossmintCommonTypes
import Web

public final class StellarEmailSigner: EmailSigner, Sendable {

    public typealias AdminType = EmailSignerData

    private let state = EmailSignerState()

    let crossmintTEE: CrossmintTEE?

    public var adminSigner: EmailSignerData {
        get async {
            guard let email = await state.email else {
                return EmailSignerData(email: "")
            }
            return EmailSignerData(email: email)
        }
    }

    public var keyType: String {
        get async {
            "ed25519"
        }
    }

    public var encoding: String {
        get async {
            "strkey"
        }
    }

    public var email: String? {
        get async {
            await state.email
        }
    }

    nonisolated public let signerType: SignerType = .email

    public init(email: String, crossmintTEE: CrossmintTEE?) {
        self.crossmintTEE = crossmintTEE
        Task {
            await state.update(email: email)
        }
    }

    public func initialize(_ service: SmartWalletService?) async throws(SignerError) {
        guard await state.isInitialized else {
            throw SignerError.invalidEmail
        }
    }

    func processMessage(_ message: String) -> String {
        message
    }
}
