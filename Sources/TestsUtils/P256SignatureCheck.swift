import CryptoKit
import Foundation

package enum P256SignatureCheck {
    package static func verifies(r: String, s: String, publicKeyBase64: String, messageBase64: String) -> Bool {
        guard let publicKeyData = Data(base64Encoded: publicKeyBase64),
              let publicKey = try? P256.Signing.PublicKey(x963Representation: publicKeyData),
              let message = Data(base64Encoded: messageBase64),
              let rData = hexData(r), let sData = hexData(s),
              let signature = try? P256.Signing.ECDSASignature(rawRepresentation: rData + sData) else {
            return false
        }
        return publicKey.isValidSignature(signature, for: message)
    }

    private static func hexData(_ hex: String) -> Data? {
        let digits = hex.hasPrefix("0x") ? String(hex.dropFirst(2)) : hex
        guard digits.count == 64 else { return nil }
        var data = Data(capacity: 32)
        var index = digits.startIndex
        while index < digits.endIndex {
            let next = digits.index(index, offsetBy: 2)
            guard let byte = UInt8(digits[index..<next], radix: 16) else { return nil }
            data.append(byte)
            index = next
        }
        return data
    }
}
