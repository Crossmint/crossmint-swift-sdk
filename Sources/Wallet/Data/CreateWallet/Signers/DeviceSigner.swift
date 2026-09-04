//
//  DeviceSigner.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 04/09/26.
//

import DeviceSigner
import Foundation

struct DeviceSigner: ApprovalSigner {
    static let locatorPrefix = "device:"

    let storage: any DeviceSignerKeyStorage
    let address: String

    var locator: String? {
        get async {
            guard let publicKeyBase64 = await storage.getKey(address: address) else { return nil }
            return Self.locator(forPublicKey: publicKeyBase64)
        }
    }

    static func locator(forPublicKey publicKeyBase64: String) -> String? {
        guard let rawKey = Data(base64Encoded: publicKeyBase64),
              rawKey.count == 65, rawKey[0] == 0x04 else { return nil }
        return "\(locatorPrefix)\(publicKeyBase64)"
    }

    static func handles(_ locator: String) -> Bool {
        locator.hasPrefix(Self.locatorPrefix)
    }

    func initialize(_ service: SmartWalletService?) async throws(SignerError) {}

    func approvals(for message: String) async throws(SignerError) -> [SignRequestApi.Approval] {
        guard let locator = await locator else {
            throw .device(.keyNotFound)
        }
        let signature: (r: String, s: String)
        do {
            signature = try await storage.signMessage(address: address, message: message)
        } catch {
            throw .device(error)
        }
        return [.device(signer: locator, signature: .init(r: signature.r, s: signature.s))]
    }
}
