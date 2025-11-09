import Foundation

public extension String {
    var noHexPrefix: String {
        if hasPrefix("0x") {
            let index = index(startIndex, offsetBy: 2)
            return String(self[index...])
        }
        return self
    }

    var withHexPrefix: String {
        if !hasPrefix("0x") {
            return "0x" + self
        }
        return self
    }

    var stringValue: String {
        if let byteArray = try? HexUtil.byteArray(fromHex: self.noHexPrefix),
            let str = String(bytes: byteArray, encoding: .utf8) {
            return str
        }

        return self
    }

    var hexData: Data? {
        let noHexPrefix = self.noHexPrefix
        if let bytes = try? HexUtil.byteArray(fromHex: noHexPrefix) {
            return Data(bytes)
        }

        return nil
    }
}
