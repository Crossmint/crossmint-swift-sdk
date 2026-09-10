//
//  SignerLocator.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 27/07/26.
//

import Logger

/// Identifies a signer registered on a wallet.
public enum SignerLocator: Codable, Sendable, Hashable {
    case device(publicKey: String)
    case email(String)
    case phone(String)
    case externalWallet(address: String)
    case passkey(credentialId: String)
    case apiKey(address: String? = nil)
    case server(address: String)
    /// A locator whose prefix this SDK version does not recognize.
    ///
    /// The raw string is kept so a signer type the backend adds after this release
    /// still loads and can be listed, compared, and removed.
    case unknown(String)

    /// Whether this locator refers to a device signer, regardless of its public key.
    public var isDevice: Bool {
        if case .device = self { true } else { false }
    }

    /// Whether this locator refers to a passkey signer, regardless of its credential ID.
    public var isPasskey: Bool {
        if case .passkey = self { true } else { false }
    }

    public var value: String {
        switch self {
        case let .device(publicKey):
            "device:\(publicKey)"
        case let .email(email):
            "email:\(email)"
        case let .phone(phone):
            "phone:\(phone)"
        case let .externalWallet(address):
            "external-wallet:\(address)"
        case let .passkey(credentialId):
            "passkey:\(credentialId)"
        case let .apiKey(address):
            address.map { "api-key:\($0)" } ?? "api-key"
        case let .server(address):
            "server:\(address)"
        case let .unknown(raw):
            raw
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        do {
            self = try SignerLocator(from: value)
        } catch {
            Logger.smartWallet.warning(LogEvents.signerLocatorUnknown, attributes: [
                "locator": value
            ])
            self = .unknown(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }

    public init(from locator: String) throws(WalletError) {
        let components = locator.split(separator: ":", maxSplits: 1)
        guard let prefix = components.first else {
            throw .signerLocatorError(locator)
        }
        let rest = components.count > 1 ? String(components[1]) : nil

        switch (prefix, rest) {
        case ("device", .some(let publicKey)):
            self = .device(publicKey: publicKey)
        case ("email", .some(let email)):
            self = .email(email)
        case ("phone", .some(let phone)):
            self = .phone(phone)
        case ("external-wallet", .some(let address)):
            self = .externalWallet(address: address)
        case ("passkey", .some(let credentialId)):
            self = .passkey(credentialId: credentialId)
        case ("api-key", let address):
            self = .apiKey(address: address)
        case ("server", .some(let address)):
            self = .server(address: address)
        default:
            throw .signerLocatorError(locator)
        }
    }
}
