import Foundation

public struct ApprovalEntry: Decodable {
    let signer: SignerApiModel
    let message: String
}

public struct SubmittedApprovalEntry: Decodable {
    let signature: String
    let submittedAt: Date
    let signer: SignerApiModel
    let message: String
}

public struct Approvals: Decodable {
    let pending: [ApprovalEntry]
    let submitted: [SubmittedApprovalEntry]

    var toDomain: Transaction.Approvals {
        Transaction.Approvals(
            pending: pending.map { Transaction.Approvals.Pending(signer: $0.signer.locator, message: $0.message) },
            submitted: submitted.map {
                Transaction.Approvals.Submitted(
                    signature: $0.signature,
                    submittedAt: $0.submittedAt,
                    signer: $0.signer.locator,
                    message: $0.message
                )
            }
        )
    }
}
