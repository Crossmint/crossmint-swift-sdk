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
    case quorum(QuorumConfig)

    private var chainTypesAcceptingSeveralMethods: Set<ChainType> { [.solana, .stellar] }

    var signers: [any Signer] {
        switch self {
        case .single(let signer): [signer]
        case .list(let signers): signers
        case .quorum(let quorum): quorum.members
        }
    }

    private var isQuorum: Bool {
        if case .quorum = self { true } else { false }
    }

    var active: any Signer {
        switch self {
        case .single(let signer): signer
        case .list(let signers): signers[0]
        case .quorum(let quorum): quorum.members[0]
        }
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
        case .quorum(let quorum):
            return .init(recoveryMethods: [await quorum.input()], delegatedSigners: delegatedSigners)
        }
    }

    func resolved(for chain: Chain) throws(WalletError) -> RecoveryInput {
        if chain.chainType == .solana, !isQuorum, signers.contains(where: { $0.signerType == .passkey }) {
            throw .passkeyRecoveryNotAllowedOnSolana
        }
        if case .quorum(let quorum) = self, quorum.members.isEmpty {
            throw .recoveryConfigRejected(
                code: .invalidConfig,
                message: "The quorum has no members"
            )
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
