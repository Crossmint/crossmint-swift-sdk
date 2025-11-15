public struct LineItemPricingCharges: Codable, Sendable {
    public var unit: Price
    public var gas: Price?
    public var salesTax: Price?
    public var shipping: Price?

    public subscript(type: LineItemPricingChargeType) -> Price? {
        get {
            switch type {
            case .unit: return unit
            case .gas: return gas
            case .salesTax: return salesTax
            case .shipping: return shipping
            }
        }
        set {
            switch type {
            case .unit:
                if let newValue = newValue {
                    unit = newValue
                }
            case .gas: gas = newValue
            case .salesTax: salesTax = newValue
            case .shipping: shipping = newValue
            }
        }
    }
}
