private struct FailableTransactionDecoding<APIModel: TransactionApiModel>: Decodable {
    let outcome: Result<APIModel, Error>

    init(from decoder: Decoder) throws {
        outcome = Result { try APIModel(from: decoder) }
    }
}

struct TransactionListApiModel<APIModel: TransactionApiModel>: Decodable {
    let transactions: [APIModel]
    let decodingErrors: [Error]

    private enum CodingKeys: String, CodingKey {
        case transactions
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let outcomes = try container.decode([FailableTransactionDecoding<APIModel>].self, forKey: .transactions)

        var models: [APIModel] = []
        var errors: [Error] = []
        for outcome in outcomes {
            switch outcome.outcome {
            case .success(let model):
                models.append(model)
            case .failure(let error):
                errors.append(error)
            }
        }
        transactions = models
        decodingErrors = errors
    }
}
