import Foundation
import BigInt

public struct Base58 {
    public enum Error: Swift.Error {
        case decodingError
        case invalidLength
        case encodingError
    }

    static let alphabet = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
    static let baseAlphabet = Array(alphabet)
    static let base: BigInt = 58

    static let alphabetMap: [Character: Int] = {
        var map = [Character: Int]()
        for (index, char) in alphabet.enumerated() {
            map[char] = index
        }
        return map
    }()

    public static func decode(_ input: String, padTo32: Bool = true) throws(Error) -> Data {
        guard !input.isEmpty else {
            return Data()
        }

        var result = BigInt(0)

        for char in input {
            guard let digitValue = alphabetMap[char] else {
                throw Error.decodingError
            }
            result = result * base + BigInt(digitValue)
        }

        let leadingOnes = input.prefix { $0 == "1" }
        let leadingZeroBytes = Data(repeating: 0, count: leadingOnes.count)

        let resultData = leadingZeroBytes + bigIntToBytes(result)

        if padTo32 {
            if resultData.count > 32 {
                throw Error.invalidLength
            }
            return resultData.count == 32 ? resultData : padTo32Bytes(resultData)
        }

        return resultData
    }

    public static func encode(_ data: Data) throws(Error) -> String {
        guard !data.isEmpty else {
            return ""
        }

        var intData = BigInt(0)
        for byte in data {
            intData = (intData << 8) | BigInt(byte)
        }

        guard intData > 0 else {
            return String(repeating: "1", count: data.prefix { $0 == 0 }.count)
        }

        var result = ""
        var value = intData

        while value > 0 {
            let remainder = value % base
            value /= base
            let digit = baseAlphabet[Int(remainder)]
            result.append(digit)
        }

        let leadingZeros = data.prefix { $0 == 0 }.count
        let prefix = String(repeating: "1", count: leadingZeros)

        return prefix + String(result.reversed())
    }

    public static func isValidSolanaAddress(_ address: String) -> Bool {
        guard address.count >= 32 && address.count <= 44 else {
            return false
        }

        guard address.first(where: { !alphabetMap.keys.contains($0) }) == nil else {
            return false
        }

        do {
            let decoded = try decode(address)
            return decoded.count == 32
        } catch {
            return false
        }
    }

    private static func bigIntToBytes(_ value: BigInt) -> Data {
        var bytes = Data()
        var val = value

        while val > 0 {
            let byte = UInt8(val & BigInt(0xff))
            bytes.insert(byte, at: 0)
            val >>= 8
        }

        return bytes
    }

    private static func padTo32Bytes(_ data: Data) -> Data {
        guard data.count < 32 else { return data }

        let paddingLength = 32 - data.count
        let padding = Data(repeating: 0, count: paddingLength)
        return padding + data
    }
}
