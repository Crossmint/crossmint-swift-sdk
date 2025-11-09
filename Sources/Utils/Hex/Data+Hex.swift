import Foundation

public extension Data {
    init?(hex: String) {
        if let byteArray = try? HexUtil.byteArray(fromHex: hex.noHexPrefix) {
            self.init(bytes: byteArray, count: byteArray.count)
        } else {
            return nil
        }
    }

    func toHexString(withPrefix: Bool) -> String {
        let mappedString = map { String(format: "%02x", $0) }.joined()
        return withPrefix ? mappedString.withHexPrefix : mappedString.noHexPrefix
    }
}
