import CrossmintCommonTypes

public protocol AdminSignerApiModel: Codable {
    var type: AdminSignerDataType { get }

    var toDomain: AdminSignerData { get }
}
