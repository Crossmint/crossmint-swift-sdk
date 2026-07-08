import CrossmintCommonTypes
import Foundation
import Http

struct RegisterSignerBody: Encodable {
    let signer: String
    let chain: String?
    let deployImmediately: Bool?

    private enum CodingKeys: String, CodingKey {
        case signer
        case chain
        case deployImmediately
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(signer, forKey: .signer)
        try container.encodeIfPresent(chain, forKey: .chain)
        try container.encodeIfPresent(deployImmediately, forKey: .deployImmediately)
    }
}

struct RegisterTypedSignerBody: Encodable {
    let signer: AdminSignerRequestApiModel
    let chain: String?
    let deployImmediately: Bool?

    private enum CodingKeys: String, CodingKey {
        case signer
        case chain
        case deployImmediately
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(signer, forKey: .signer)
        try container.encodeIfPresent(chain, forKey: .chain)
        try container.encodeIfPresent(deployImmediately, forKey: .deployImmediately)
    }
}

extension Endpoint {
    static func meWalletSigners(chainType: ChainType, headers: [String: String] = [:], body: Data) -> Endpoint {
        Endpoint(
            path: "/2025-06-09/wallets/me:\(chainType.rawValue)/signers",
            method: .post,
            headers: headers,
            body: body
        )
    }
}
