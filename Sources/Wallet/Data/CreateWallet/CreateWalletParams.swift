import CrossmintCommonTypes

public struct DelegatedSignerEntry: Encodable {
    public let signer: String  // e.g. "device:<base64_uncompressed_pubkey>"
}

public struct CreateWalletParams: Encodable {
    struct InputConfig: Encodable {
        let adminSigner: AdminSignerRequestApiModel
        let delegatedSigners: [DelegatedSignerEntry]?

        init(adminSigner: any AdminSignerData, delegatedSigners: [DelegatedSignerEntry]?) {
            self.adminSigner = AdminSignerRequestApiModel(adminSigner)
            self.delegatedSigners = delegatedSigners
        }
    }

    let chainType: ChainType
    let type: WalletType
    let config: InputConfig
}
