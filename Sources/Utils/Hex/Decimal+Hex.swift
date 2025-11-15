import Foundation

extension Decimal {
    public init?(hexString: String) {
        let hex = hexString.hasPrefix("0x") ? String(hexString.dropFirst(2)) : hexString
        guard let number = Decimal(string: hex, locale: nil) else { return nil }
        self = number
    }
}
