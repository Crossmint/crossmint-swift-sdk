import Foundation

public protocol SignatureApiModel: Decodable {
    var id: String { get }
    var type: String { get }
    var chainType: String? { get }
    var walletType: String? { get }
    var status: String { get }
    var outputSignature: String? { get }
    var approvals: Approvals { get }
    var createdAt: Date { get }
}

extension SignatureApiModel {
    var awaitsQuorumMembers: Bool {
        guard SignerStatus.from(status) == .awaitingApproval else { return false }
        return approvals.quorums.contains { $0.quorumApprovals.remaining > 0 }
    }
}
