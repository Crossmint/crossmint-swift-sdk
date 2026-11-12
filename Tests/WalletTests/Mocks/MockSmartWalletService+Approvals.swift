//
//  MockSmartWalletService+Approvals.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 12/11/26.
//

import CrossmintCommonTypes
import Foundation

@testable import Wallet

extension MockSmartWalletService {
    func addSigner(
        _ entry: DelegatedSignerEntry,
        chainType: ChainType,
        chainName: String,
        deployImmediately: Bool?,
        approver: SignerLocator?
    ) async throws(WalletError) -> AddDelegatedSignerResponse {
        try await addSigner(
            entry,
            chainType: chainType,
            chainName: chainName,
            deployImmediately: deployImmediately,
            approval: approver.map { SignerChangeApproval(approver: $0) }
        )
    }

    func registerTypedSigner(
        _ signer: any AdminSignerData,
        chainType: ChainType,
        chainName: String,
        deployImmediately: Bool?,
        approver: SignerLocator?
    ) async throws(WalletError) -> AddDelegatedSignerResponse {
        try await registerTypedSigner(
            signer,
            chainType: chainType,
            chainName: chainName,
            deployImmediately: deployImmediately,
            approval: approver.map { SignerChangeApproval(approver: $0) }
        )
    }

    func removeSigner(
        _ signerLocator: String,
        chainType: ChainType,
        chainName: String,
        approver: SignerLocator?
    ) async throws(TransactionError) -> any TransactionApiModel {
        try await removeSigner(
            signerLocator,
            chainType: chainType,
            chainName: chainName,
            approval: approver.map { SignerChangeApproval(approver: $0) }
        )
    }

    func addRecoveryMethod(
        _ recoveryMethod: any AdminSignerData,
        chainType: ChainType,
        chainName: String,
        approver: SignerLocator
    ) async throws(WalletError) -> any TransactionApiModel {
        try await addRecoveryMethod(
            recoveryMethod,
            chainType: chainType,
            chainName: chainName,
            approval: SignerChangeApproval(approver: approver)
        )
    }

    func removeRecoveryMethod(
        _ locator: SignerLocator,
        chainType: ChainType,
        chainName: String,
        approver: SignerLocator
    ) async throws(WalletError) -> any TransactionApiModel {
        try await removeRecoveryMethod(
            locator,
            chainType: chainType,
            chainName: chainName,
            approval: SignerChangeApproval(approver: approver)
        )
    }
}
