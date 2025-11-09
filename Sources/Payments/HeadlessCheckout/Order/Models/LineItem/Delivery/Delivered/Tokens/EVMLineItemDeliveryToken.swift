public struct EvmLineItemDeliveryToken: CommonLineItemDeliveryToken {
    public var locator: TokenLocator
    public var contractAddress: String
    public var tokenId: String
}
