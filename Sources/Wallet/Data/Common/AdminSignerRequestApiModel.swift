import CrossmintCommonTypes

struct AdminSignerRequestApiModel: Encodable {
    private let data: any AdminSignerData

    init(_ data: any AdminSignerData) {
        self.data = data
    }

    private enum CodingKeys: String, CodingKey {
        case type, email, phone, address, id, name, publicKey, validatorContractVersion
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(data.type.rawValue, forKey: .type)
        switch data {
        case let d as EmailSignerData:
            try container.encode(d.email, forKey: .email)
        case let d as PhoneSignerData:
            try container.encode(d.phone, forKey: .phone)
        case let d as ExternalWalletSignerData:
            try container.encode(d.address, forKey: .address)
        case let d as ServerSignerData:
            try container.encode(d.address, forKey: .address)
        case let d as PasskeySignerData:
            try container.encode(d.id, forKey: .id)
            try container.encode(d.name, forKey: .name)
            try container.encode(PasskeyPublicKey(d.publicKey), forKey: .publicKey)
            try container.encodeIfPresent(d.validatorContractVersion, forKey: .validatorContractVersion)
        case is ApiKeySignerData:
            break
        default:
            break
        }
    }
}

private struct PasskeyPublicKey: Encodable {
    let x: String
    let y: String

    init(_ key: PasskeySignerData.PublicKey) {
        x = key.x
        y = key.y
    }
}
