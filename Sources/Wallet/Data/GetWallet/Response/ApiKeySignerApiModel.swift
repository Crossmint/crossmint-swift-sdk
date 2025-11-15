import CrossmintCommonTypes

public struct ApiKeySignerApiModel: AdminSignerApiModel {
    public let type: AdminSignerDataType
    public let address: String
    public let locator: String

    public var toDomain: any AdminSignerData {
        ApiKeySignerData()
    }
}
