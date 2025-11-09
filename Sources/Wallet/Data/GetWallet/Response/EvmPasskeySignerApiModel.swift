import CrossmintCommonTypes

public struct EvmPasskeySignerApiModel: AdminSignerApiModel {
    public let type: AdminSignerDataType
    public let id: String
    public let name: String
    public let publicKey: PublicKey
    public let validatorContractVersion: String
    public let locator: String

    public struct PublicKey: Codable {
        let x: String
        let y: String

        var toDomain: PasskeySignerData.PublicKey {
            PasskeySignerData.PublicKey(x: x, y: y)
        }
    }

    public var toDomain: any AdminSignerData {
        PasskeySignerData(
            id: id,
            name: name,
            publicKey: publicKey.toDomain,
            validatorContractVersion: validatorContractVersion
        )
    }
}
