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

    private var chainsWithRecoveryList: Set<ChainType> { [.solana, .stellar] }

    var signers: [any Signer] {
        switch self {
        case .single(let signer): [signer]
        case .list(let signers): signers
        }
    }

    var active: any Signer {
        switch self {
        case .single(let signer): signer
        case .list(let signers): signers[0]
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
        }
    }

    func assertValid(for chain: Chain) throws(WalletError) {
        guard case .list(let signers) = self else { return }
        guard !signers.isEmpty else {
            throw .walletGeneric("At least one recovery signer is required")
        }
        guard chainsWithRecoveryList.contains(chain.chainType) else {
            throw .recoveryConfigRejected(
                code: .notSupportedOnChain,
                message: "Multiple recovery signers are not supported on \(chain.name) yet. "
                    + "Pass a single recovery signer."
            )
        }
    }
}
