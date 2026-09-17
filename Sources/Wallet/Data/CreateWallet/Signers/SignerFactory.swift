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
    static func email(_ email: String, chainType: ChainType) -> any Signer {
        switch chainType {
        case .evm, .unknown:
            EVMEmailSigner(email: email, crossmintTEE: CrossmintTEE.shared)
        case .solana:
            SolanaEmailSigner(email: email, crossmintTEE: CrossmintTEE.shared)
        case .stellar:
            StellarEmailSigner(email: email, crossmintTEE: CrossmintTEE.shared)
        }
    }

    @MainActor
    static func phone(_ phone: String, channel: OTPDeliveryChannel?, chainType: ChainType) -> any Signer {
        PhoneSigner(phone: phone, channel: channel, chainType: chainType, crossmintTEE: CrossmintTEE.shared)
    }

    /// The signer the SDK drives for a recovery method the API reports, or `nil` when the SDK cannot
    /// sign with it on its own: a passkey needs the relying-party host the API does not store, and
    /// external-wallet and server signers approve outside the SDK.
    @MainActor
    static func recovery(_ data: any AdminSignerData, chainType: ChainType) -> (any Signer)? {
        switch data {
        case let data as EmailSignerData:
            email(data.email, chainType: chainType)
        case let data as PhoneSignerData:
            phone(data.phone, channel: nil, chainType: chainType)
        case let data as ApiKeySignerData:
            ApiKeySigner(adminSigner: data)
        default:
            nil
        }
    }
}
