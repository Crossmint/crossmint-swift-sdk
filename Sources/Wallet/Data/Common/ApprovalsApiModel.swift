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

public struct QuorumApprovalEntry: Decodable {
    struct Progress: Decodable {
        let threshold: Int
        let remaining: Int
        let pending: [MemberEntry]
        let submitted: [SubmittedMemberEntry]
    }

    struct MemberEntry: Decodable {
        let member: SignerApiModel
        let message: String
    }

    struct SubmittedMemberEntry: Decodable {
        let member: SignerApiModel
        let message: String
        let signature: String
        let submittedAt: Date
    }

    let signer: SignerApiModel
    let quorumApprovals: Progress

    static func matches(_ decoder: Decoder) throws -> Bool {
        try decoder.container(keyedBy: CodingKeys.self).contains(.quorumApprovals)
    }

    var toDomain: Transaction.Approvals.QuorumProgress {
        Transaction.Approvals.QuorumProgress(
            signer: SignerLocator(orUnknown: signer.locator),
            threshold: quorumApprovals.threshold,
            remaining: quorumApprovals.remaining,
            pending: quorumApprovals.pending.map {
                Transaction.Approvals.Pending(signer: $0.member.locator, message: $0.message)
            },
            submitted: quorumApprovals.submitted.map {
                Transaction.Approvals.Submitted(
                    signature: $0.signature,
                    submittedAt: $0.submittedAt,
                    signer: $0.member.locator,
                    message: $0.message
                )
            }
        )
    }
}

public struct Approvals: Decodable {
    let pending: [ApprovalEntry]
    let submitted: [SubmittedApprovalEntry]
    let quorums: [QuorumApprovalEntry]
    let required: Int?

    private enum CodingKeys: String, CodingKey {
        case pending, submitted, required
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        var quorums: [QuorumApprovalEntry] = []

        var pendingList = try container.nestedUnkeyedContainer(forKey: .pending)
        var pending: [ApprovalEntry] = []
        while !pendingList.isAtEnd {
            let entry = try pendingList.superDecoder()
            if try QuorumApprovalEntry.matches(entry) {
                quorums.append(try QuorumApprovalEntry(from: entry))
            } else {
                pending.append(try ApprovalEntry(from: entry))
            }
        }

        var submittedList = try container.nestedUnkeyedContainer(forKey: .submitted)
        var submitted: [SubmittedApprovalEntry] = []
        while !submittedList.isAtEnd {
            let entry = try submittedList.superDecoder()
            if try QuorumApprovalEntry.matches(entry) {
                quorums.append(try QuorumApprovalEntry(from: entry))
            } else {
                submitted.append(try SubmittedApprovalEntry(from: entry))
            }
        }

        self.pending = pending
        self.submitted = submitted
        self.quorums = quorums
        required = try container.decodeIfPresent(Int.self, forKey: .required)
    }

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
            },
            quorums: quorums.map(\.toDomain)
        )
    }
}
