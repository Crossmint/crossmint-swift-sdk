//
//  SignerFactory.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 17/09/26.
//

import CrossmintCommonTypes
import Web

enum SignerFactory {
    @MainActor
    static func email(_ email: String, chainType: ChainType) -> (any Signer)? {
        switch chainType {
        case .evm:
            EVMEmailSigner(email: email, crossmintTEE: CrossmintTEE.shared)
        case .solana:
            SolanaEmailSigner(email: email, crossmintTEE: CrossmintTEE.shared)
        case .stellar:
            StellarEmailSigner(email: email, crossmintTEE: CrossmintTEE.shared)
        case .unknown:
            nil
        }
    }

    @MainActor
    static func phone(_ phone: String, channel: OTPDeliveryChannel?, chainType: ChainType) -> (any Signer)? {
        guard chainType != .unknown else { return nil }
        return PhoneSigner(phone: phone, channel: channel, chainType: chainType, crossmintTEE: CrossmintTEE.shared)
    }

    static func passkey(_ data: PasskeySignerData, host: String) async -> any Signer {
        await PasskeySigner(name: data.name, host: host).updateAdminSigner(data)
    }

    @MainActor
    static func recovery(
        _ data: any AdminSignerData,
        chainType: ChainType,
        passkeyHost: String?
    ) async -> (any Signer)? {
        switch data {
        case let data as EmailSignerData:
            email(data.email, chainType: chainType)
        case let data as PhoneSignerData:
            phone(data.phone, channel: nil, chainType: chainType)
        case let data as ApiKeySignerData:
            ApiKeySigner(adminSigner: data)
        case let data as PasskeySignerData:
            if let passkeyHost {
                await passkey(data, host: passkeyHost)
            } else {
                nil
            }
        default:
            nil
        }
    }

    @MainActor
    static func delegated(
        _ locator: SignerLocator,
        chainType: ChainType,
        passkeyHost: String?
    ) async -> (any Signer)? {
        switch locator {
        case .email(let address):
            email(address, chainType: chainType)
        case .phone(let number):
            phone(number, channel: nil, chainType: chainType)
        case .apiKey(let address):
            ApiKeySigner(adminSigner: ApiKeySignerData(address: address))
        case .passkey(let credentialId):
            if let passkeyHost {
                await passkey(
                    PasskeySignerData(id: credentialId, name: credentialId, publicKey: .init(x: "0", y: "0")),
                    host: passkeyHost
                )
            } else {
                nil
            }
        case .device, .externalWallet, .server, .unknown:
            nil
        }
    }
}
