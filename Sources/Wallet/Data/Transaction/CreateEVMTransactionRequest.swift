import CrossmintCommonTypes

public struct CreateEVMTransactionRequest: TransactionRequest {
    let contractAddress: EVMAddress
    let value: String
    let data: String
    let chain: EVMChain
    let signer: String

    enum CodingKeys: String, CodingKey {
        case params
    }

    struct Params: Encodable {
        let calls: [Call]
        let chain: String
        let signer: String
    }

    struct Call: Encodable {
        let to: String
        let value: String
        let data: String
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let params = Params(
            calls: [Call(to: contractAddress.address, value: value, data: data)],
            chain: chain.name,
            signer: signer
        )
        try container.encode(params, forKey: .params)
    }
}
