public struct FundWalletApiRequest: Codable {
    let token: String
    let amount: Int
    let chain: String

    public init(token: String, amount: Int, chain: String) {
        self.token = token
        self.amount = amount
        self.chain = chain
    }
}
