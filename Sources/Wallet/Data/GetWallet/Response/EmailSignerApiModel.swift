import CrossmintCommonTypes

public struct EmailSignerApiModel: AdminSignerApiModel {
    public let type: AdminSignerDataType
    public let email: String
    public let locator: String

    public var toDomain: any AdminSignerData {
        EmailSignerData(email: email)
    }
}
