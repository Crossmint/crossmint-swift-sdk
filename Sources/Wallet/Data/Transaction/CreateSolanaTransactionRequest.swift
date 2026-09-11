import Foundation

public struct CreateSolanaTransactionRequest: TransactionRequest, Codable {
    public let transaction: String
    /// Locator of the signer that authorizes the transaction. When `nil`, the wallet's first
    /// recovery signer authorizes it.
    public let signer: String?

    public init(transaction: String, signer: String? = nil) {
        self.transaction = transaction
        self.signer = signer
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        let params = Params(transaction: transaction, signer: signer)
        try container.encode(params, forKey: .params)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let params = try container.decode(Params.self, forKey: .params)

        self.transaction = params.transaction
        self.signer = params.signer
    }

    private enum CodingKeys: String, CodingKey {
        case params
    }

    private struct Params: Codable {
        let transaction: String
        let signer: String?
    }
}
