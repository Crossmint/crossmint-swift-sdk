import CrossmintCommonTypes

public struct ServerSignerApiModel: AdminSignerApiModel {
    public let type: AdminSignerDataType
    public let address: String
    public let locator: String

    public var toDomain: any AdminSignerData {
        ServerSignerData(address: address)
    }
}
