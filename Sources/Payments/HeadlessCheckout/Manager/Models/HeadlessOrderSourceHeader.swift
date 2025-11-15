struct OrderSourceSDKMetadata: Encodable {
    let version: String
    let name: String = "crossmint-swift-sdk"
}
struct OrderSourceHeader: Encodable {
    let type = "embedded"
    let sdkMetadata: OrderSourceSDKMetadata
}
