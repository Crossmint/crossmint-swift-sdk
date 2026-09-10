import CrossmintCommonTypes
import Foundation
import Http

struct RegisterSignerBody: Encodable {
    let signer: DelegatedSignerEntry.Signer
    let chain: String?
    let deployImmediately: Bool?
}

struct RegisterTypedSignerBody: Encodable {
    let signer: AdminSignerRequestApiModel
    let chain: String?
    let deployImmediately: Bool?
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
