//
//  Wallet+Quorum.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 26/10/26.
//

import CrossmintCommonTypes
import Logger

extension Wallet {
    internal func isQuorum(_ locator: String?) -> Bool {
        guard let locator, case .quorum = try? SignerLocator(from: locator) else { return false }
        return true
    }

    internal func quorumRole(of locator: SignerLocator) async throws(TransactionError) -> SignerLocator? {
        let quorums = config.quorumLocators(withMember: locator)
        guard !quorums.isEmpty, !config.containsRecoveryMethod(locator) else { return nil }
        let registered: Bool
        do {
            registered = try await fetchSignerRegistration(locator)
        } catch {
            throw .transactionGeneric(error.message)
        }
        if registered { return nil }
        guard quorums.count == 1 else { throw .quorumSelectionAmbiguous(quorums: quorums) }
        return quorums[0]
    }

    internal func approveAsQuorumMembers(
        of quorums: [Transaction.Approvals.QuorumProgress],
        transactionId: String
    ) async throws(TransactionError) {
        let memberApprovals = try await heldMemberApprovals(of: quorums)
        guard !memberApprovals.isEmpty else { return }
        _ = try await smartWalletService.signTransaction(
            .init(
                transactionId: transactionId,
                apiRequest: SignRequestApi(approvals: memberApprovals),
                chainType: chain.chainType
            )
        )
    }

    internal func heldMemberApprovals(
        of quorums: [Transaction.Approvals.QuorumProgress]
    ) async throws(TransactionError) -> [SignRequestApi.Approval] {
        var memberApprovals: [SignRequestApi.Approval] = []
        for quorum in quorums where quorum.remaining > 0 {
            for member in quorum.pending {
                guard (try? await approvalSigner(for: member.signer)) != nil else {
                    Logger.smartWallet.info(LogEvents.walletApproveQuorumMemberSkipped, attributes: [
                        "quorum": quorum.signer.value,
                        "member": member.signer
                    ])
                    continue
                }
                memberApprovals += try await signRequest(for: member.signer, message: member.message).approvals
            }
        }
        return memberApprovals
    }
}
