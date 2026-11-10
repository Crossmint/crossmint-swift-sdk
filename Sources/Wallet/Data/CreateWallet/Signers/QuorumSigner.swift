//
//  QuorumSigner.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 20/10/26.
//

import CrossmintCommonTypes

struct QuorumSigner: Signer {
    let threshold: Int
    let members: [any Signer]

    var signerType: SignerType { .quorum }

    var adminSigner: QuorumSignerInput {
        get async {
            var memberData: [any AdminSignerData] = []
            for member in members {
                memberData.append(await member.adminSigner)
            }
            return QuorumSignerInput(threshold: threshold, members: memberData)
        }
    }

    var locator: SignerLocator? {
        get async { nil }
    }

    func initialize(_ service: SmartWalletService?) async throws(SignerError) {
        for member in members {
            try await member.initialize(service)
        }
    }

    func sign(message: String) async throws(SignerError) -> String {
        throw .invalidSigner
    }

    func approvals(withSignature signature: String) async throws(SignerError) -> [SignRequestApi.Approval] {
        throw .invalidSigner
    }
}

struct QuorumSignerInput: AdminSignerData {
    let threshold: Int
    let members: [any AdminSignerData]

    var type: AdminSignerDataType { .quorum }
    var locatorId: String { "" }
}
