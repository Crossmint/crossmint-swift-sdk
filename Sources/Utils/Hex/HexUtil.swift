import Foundation

public enum HexConversionError: Error {
    case invalidDigit
    case stringNotEven
}

public class HexUtil {
    public static func convert(
        hexDigit digit: UnicodeScalar
    ) throws(HexConversionError) -> UInt8 {
        switch digit {
        case "0"..."9":
            guard let first = "0".unicodeScalars.first else { throw HexConversionError.invalidDigit }
            return UInt8(digit.value - first.value)
        case "a"..."f":
            guard let first = "a".unicodeScalars.first else { throw HexConversionError.invalidDigit }
            return UInt8(digit.value - first.value + 10)
        case "A"..."F":
            guard let first = "A".unicodeScalars.first else { throw HexConversionError.invalidDigit }
            return UInt8(digit.value - first.value + 10)
        default:
            throw HexConversionError.invalidDigit
        }
    }

    public static func byteArray(fromHex string: String) throws -> [UInt8] {
        var iterator = string.unicodeScalars.makeIterator()
        var byteArray: [UInt8] = []

        while let msn = iterator.next() {
            if let lsn = iterator.next() {
                do {
                    let convertedMsn = try convert(hexDigit: msn)
                    let convertedLsn = try convert(hexDigit: lsn)
                    byteArray += [convertedMsn << 4 | convertedLsn]
                } catch {
                    throw error
                }
            } else {
                throw HexConversionError.stringNotEven
            }
        }
        return byteArray
    }
}
