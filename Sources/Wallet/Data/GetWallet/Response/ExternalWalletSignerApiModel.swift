import CrossmintCommonTypes

public struct ExternalWalletSignerApiModel: AdminSignerApiModel {
    public let type: AdminSignerDataType
    public let address: String
    public let locator: String

    public var toDomain: any AdminSignerData {
        ExternalWalletSignerData(address: address)
    }
}
