//
//  ExternalWalletSigner.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 24/09/26.
//

import CrossmintCommonTypes

struct ExternalWalletSigner: Signer {
    typealias AdminType = ExternalWalletSignerData

    let signerType: SignerType = .externalWallet
    let adminSigner: ExternalWalletSignerData
    private let onSign: @Sendable (String) async throws -> String

    init(address: String, onSign: @escaping @Sendable (String) async throws -> String) {
        self.adminSigner = ExternalWalletSignerData(address: address)
        self.onSign = onSign
    }

    func initialize(_ service: SmartWalletService?) async throws(SignerError) {}

    func sign(message: String) async throws(SignerError) -> String {
        do {
            return try await onSign(message)
        } catch let error as SignerError {
            throw error
        } catch is CancellationError {
            throw .cancelled
        } catch {
            throw .signingFailed
        }
    }

    func approvals(withSignature signature: String) async throws(SignerError) -> [SignRequestApi.Approval] {
        [.keypair(signer: adminSigner.locator, signature: signature)]
    }
}
