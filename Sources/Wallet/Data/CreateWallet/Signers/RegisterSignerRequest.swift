import CrossmintCommonTypes
import Foundation
import Http

struct RegisterSignerBody: Encodable {
    let signer: String
    let chain: String?
}

struct RegisterTypedSignerBody: Encodable {
    let signerData: any AdminSignerData
    let chain: String?

    enum CodingKeys: String, CodingKey { case signer, chain }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let signerEncoder = container.superEncoder(forKey: .signer)
        try signerData.encode(to: signerEncoder)
        try container.encodeIfPresent(chain, forKey: .chain)
    }
}

extension Endpoint {
    static func meWalletSigners(chainType: ChainType, headers: [String: String], body: Data) -> Endpoint {
        Endpoint(
            path: "/2025-06-09/wallets/me:\(chainType.rawValue)/signers",
            method: .post,
            headers: headers,
            body: body
        )
    }
}
