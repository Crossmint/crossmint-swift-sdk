//
//  Wallet+Quorum.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 26/10/26.
//

import CrossmintCommonTypes
import Logger

extension Wallet {
    internal func quorumRole(of locator: SignerLocator) async throws(TransactionError) -> SignerLocator? {
        let quorums = config.recoveryMethods
            .compactMap { $0 as? QuorumSignerData }
            .filter { quorum in quorum.members.contains { (try? SignerLocator(from: $0.locator)) == locator } }
            .map { SignerLocator.quorum(id: $0.id) }
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
        var memberApprovals: [SignRequestApi.Approval] = []
        var signedMembers = 0
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
                signedMembers += 1
            }
        }
        guard signedMembers > 0 else { return }
        _ = try await smartWalletService.signTransaction(
            .init(
                transactionId: transactionId,
                apiRequest: SignRequestApi(approvals: memberApprovals),
                chainType: chain.chainType
            )
        )
    }
}
