//
//  RecoveryInput.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 09/09/26.
//

import CrossmintCommonTypes

enum RecoveryInput {
    case single(any Signer)
    case list([any Signer])

    private var chainTypesAcceptingSeveralMethods: Set<ChainType> { [.solana, .stellar] }

    var signers: [any Signer] {
        switch self {
        case .single(let signer): [signer]
        case .list(let signers): signers
        }
    }

    var active: any Signer {
        let first = signers[0]
        guard let quorum = first as? QuorumSigner, let member = quorum.members.first else { return first }
        return member
    }

    func defaultSigner(for first: any AdminSignerData) async -> any Signer {
        guard case .list(let signers) = self else { return active }
        for signer in signers where await signer.adminSigner.locator == first.locator {
            return signer
        }
        return active
    }

    func inputConfig(delegatedSigners: [DelegatedSignerEntry]?) async -> CreateWalletParams.InputConfig {
        switch self {
        case .single(let signer):
            return .init(adminSigner: await signer.adminSigner, delegatedSigners: delegatedSigners)
        case .list(let signers):
            var methods: [any AdminSignerData] = []
            for signer in signers {
                methods.append(await signer.adminSigner)
            }
            return .init(recoveryMethods: methods, delegatedSigners: delegatedSigners)
        }
    }

    func resolved(for chain: Chain) throws(WalletError) -> RecoveryInput {
        if chain.chainType == .solana, signers.contains(where: { $0.signerType == .passkey }) {
            throw .passkeyRecoveryNotAllowedOnSolana
        }
        if signers.contains(where: { ($0 as? QuorumSigner)?.members.isEmpty == true }) {
            throw .recoveryConfigRejected(code: .invalidConfig, message: "The quorum has no members")
        }
        guard case .list(let signers) = self else { return self }
        guard let first = signers.first else {
            throw .recoveryConfigRejected(
                code: .invalidConfig,
                message: "At least one recovery method is required"
            )
        }
        guard !chainTypesAcceptingSeveralMethods.contains(chain.chainType) else { return self }
        guard signers.count == 1 else {
            throw .recoveryConfigRejected(
                code: .notSupportedOnChain,
                message: "Multiple recovery methods are not supported on \(chain.name) yet. "
                    + "Pass a single recovery method."
            )
        }
        return .single(first)
    }
}
