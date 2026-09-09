//
//  RecoveryInput.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 09/09/26.
//

import CrossmintCommonTypes

/// The recovery signers a caller supplied, keeping track of which overload they used.
///
/// The wire shape follows the overload: one signer goes under the legacy `adminSigner` key,
/// a list goes under `recovery`, even when the list has a single entry.
enum RecoveryInput {
    case single(any Signer)
    case list([any Signer])

    enum Request {
        case adminSigner(any AdminSignerData)
        case recovery([any AdminSignerData])
    }

    /// Chains whose create endpoint accepts a list of recovery signers.
    private static let chainsWithRecoveryList: Set<ChainType> = [.solana, .stellar]

    var signers: [any Signer] {
        switch self {
        case .single(let signer): [signer]
        case .list(let signers): signers
        }
    }

    /// The signer the wallet signs with until ``Wallet/useSigner(_:)`` selects another one.
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
