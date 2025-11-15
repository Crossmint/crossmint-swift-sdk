import Foundation

public struct TransactionErrorApiModel: Decodable {
    public let reason: String
    public let message: String
    public let revert: Revert?

    public struct Revert: Decodable {
        public let type: String
        public let reason: String
        public let simulationLink: URL

        var toDomain: Transaction.Error.Revert {
            Transaction.Error.Revert(
                type: type,
                reason: reason,
                simulationLink: simulationLink
            )
        }
    }

    var toDomain: Transaction.Error {
        Transaction.Error(
            reason: reason,
            message: message,
            revert: revert?.toDomain
        )
    }
}
