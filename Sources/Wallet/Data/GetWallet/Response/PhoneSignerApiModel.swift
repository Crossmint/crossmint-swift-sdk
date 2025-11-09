import CrossmintCommonTypes

public struct PhoneSignerApiModel: AdminSignerApiModel {
    public let type: AdminSignerDataType
    public let phone: String
    public let locator: String

    public var toDomain: any AdminSignerData {
        PhoneSignerData(phone: phone)
    }
}
