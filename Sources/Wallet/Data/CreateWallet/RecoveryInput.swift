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

    enum Request {
        case adminSigner(any AdminSignerData)
        case recovery([any AdminSignerData])
    }

    private static let chainsWithRecoveryList: Set<ChainType> = [.solana, .stellar]

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

    var request: Request {
        get async {
            switch self {
            case .single(let signer):
                return .adminSigner(await signer.adminSigner)
            case .list(let signers):
                var methods: [any AdminSignerData] = []
                for signer in signers {
                    methods.append(await signer.adminSigner)
                }
                return .recovery(methods)
            }
        }
    }

    func assertValid(for chain: Chain) throws(WalletError) {
        guard case .list(let signers) = self else { return }
        guard !signers.isEmpty else {
            throw .walletGeneric("At least one recovery signer is required")
        }
        guard Self.chainsWithRecoveryList.contains(chain.chainType) else {
            throw .recoveryConfigRejected(
                code: WalletError.RECOVERY_NOT_SUPPORTED_ON_CHAIN,
                message: "Multiple recovery signers are not supported on \(chain.name) yet. "
                    + "Pass a single recovery signer."
            )
        }
    }
}
