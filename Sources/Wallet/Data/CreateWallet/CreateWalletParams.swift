import CrossmintCommonTypes

public struct DelegatedSignerEntry: Encodable {
    public let signer: String  // e.g. "device:<base64_uncompressed_pubkey>"
}

public struct CreateWalletParams: Encodable {
    struct InputConfig: Encodable {
        let adminSigner: AdminSignerRequestApiModel?
        let recovery: [AdminSignerRequestApiModel]?
        let delegatedSigners: [DelegatedSignerEntry]?

        init(adminSigner: any AdminSignerData, delegatedSigners: [DelegatedSignerEntry]?) {
            self.adminSigner = AdminSignerRequestApiModel(adminSigner)
            self.recovery = nil
            self.delegatedSigners = delegatedSigners
        }

        init(recovery: [any AdminSignerData], delegatedSigners: [DelegatedSignerEntry]?) {
            self.adminSigner = nil
            self.recovery = recovery.map(AdminSignerRequestApiModel.init)
            self.delegatedSigners = delegatedSigners
        }

        private enum CodingKeys: String, CodingKey {
            case adminSigner, recovery, delegatedSigners
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(adminSigner, forKey: .adminSigner)
            try container.encodeIfPresent(recovery, forKey: .recovery)
            try container.encodeIfPresent(delegatedSigners, forKey: .delegatedSigners)
        }
    }

    let chainType: ChainType
    let type: WalletType
    let config: InputConfig
}
