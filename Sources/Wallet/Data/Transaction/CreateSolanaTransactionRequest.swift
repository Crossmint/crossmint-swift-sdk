import Foundation

public struct CreateSolanaTransactionRequest: TransactionRequest, Codable {
    public let transaction: String
    /// Locator of the signer that authorizes the transaction. When `nil`, the wallet's first
    /// recovery signer authorizes it.
    public let signer: String?
    /// Locators of the quorum members that approve, when `signer` is a quorum.
    public let approvingMembers: [String]?

    public init(transaction: String, signer: String? = nil, approvingMembers: [String]? = nil) {
        self.transaction = transaction
        self.signer = signer
        self.approvingMembers = approvingMembers
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        let params = Params(transaction: transaction, signer: signer, approvingMembers: approvingMembers)
        try container.encode(params, forKey: .params)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let params = try container.decode(Params.self, forKey: .params)

        self.transaction = params.transaction
        self.signer = params.signer
        self.approvingMembers = params.approvingMembers
    }

    private enum CodingKeys: String, CodingKey {
        case params
    }

    private struct Params: Codable {
        let transaction: String
        let signer: String?
        let approvingMembers: [String]?
    }
}
