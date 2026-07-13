struct TransactionListApiModel<APIModel: TransactionApiModel>: Decodable {
    let transactions: [APIModel]
}
