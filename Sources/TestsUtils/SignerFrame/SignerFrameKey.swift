import Foundation
import P256K

/// The secp256k1 key the scripted frame signs with; the real frame signs inside the TEE.
package final class SignerFrameKey: @unchecked Sendable {
    private let privateKey: P256K.Signing.PrivateKey

    package init() throws {
        privateKey = try P256K.Signing.PrivateKey(format: .uncompressed)
    }

    package func sign(hexBytes: String) throws -> String {
        let signature = try privateKey.signature(for: Self.data(hex: hexBytes))
        return "0x" + signature.dataRepresentation.map { String(format: "%02x", $0) }.joined()
    }

    package func verifies(signatureHex: String, hexBytes: String) -> Bool {
        guard let signature = try? P256K.Signing.ECDSASignature(dataRepresentation: Self.data(hex: signatureHex)) else {
            return false
        }
        return privateKey.publicKey.isValidSignature(signature, for: Self.data(hex: hexBytes))
    }

    private static func data(hex: String) -> Data {
        let digits = hex.hasPrefix("0x") ? String(hex.dropFirst(2)) : hex
        var data = Data(capacity: digits.count / 2)
        var index = digits.startIndex
        while index < digits.endIndex {
            let next = digits.index(index, offsetBy: 2, limitedBy: digits.endIndex) ?? digits.endIndex
            data.append(UInt8(digits[index..<next], radix: 16) ?? 0)
            index = next
        }
        return data
    }
}
