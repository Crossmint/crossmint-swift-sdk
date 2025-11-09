import Foundation
import Testing
@testable import Utils

@Suite("HexUtil Tests")
struct HexUtilTests {

    @Test("Convert valid hex digits")
    func testValidHexDigitConversion() throws {
        #expect(try HexUtil.convert(hexDigit: "0") == 0)
        #expect(try HexUtil.convert(hexDigit: "9") == 9)
        #expect(try HexUtil.convert(hexDigit: "a") == 10)
        #expect(try HexUtil.convert(hexDigit: "f") == 15)
        #expect(try HexUtil.convert(hexDigit: "A") == 10)
        #expect(try HexUtil.convert(hexDigit: "F") == 15)
    }

    @Test("Convert invalid hex digits throws error")
    func testInvalidHexDigitConversion() throws {
        #expect(throws: HexConversionError.invalidDigit) {
            try HexUtil.convert(hexDigit: "g")
        }

        #expect(throws: HexConversionError.invalidDigit) {
            try HexUtil.convert(hexDigit: "G")
        }

        #expect(throws: HexConversionError.invalidDigit) {
            try HexUtil.convert(hexDigit: "z")
        }

        #expect(throws: HexConversionError.invalidDigit) {
            try HexUtil.convert(hexDigit: "#")
        }
    }

    @Test("Convert valid hex strings to byte arrays")
    func testValidByteArrayFromHex() throws {
        #expect(try HexUtil.byteArray(fromHex: "00") == [0x00])
        #expect(try HexUtil.byteArray(fromHex: "ff") == [0xff])
        #expect(try HexUtil.byteArray(fromHex: "FF") == [0xff])
        #expect(try HexUtil.byteArray(fromHex: "deadbeef") == [0xde, 0xad, 0xbe, 0xef])
        #expect(try HexUtil.byteArray(fromHex: "0123456789abcdef") == [0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef])
        #expect(try HexUtil.byteArray(fromHex: "") == [])
    }

    @Test("Convert invalid hex strings throws errors")
    func testInvalidByteArrayFromHex() throws {
        #expect(throws: HexConversionError.stringNotEven) {
            try HexUtil.byteArray(fromHex: "0")
        }

        #expect(throws: HexConversionError.stringNotEven) {
            try HexUtil.byteArray(fromHex: "abc")
        }

        #expect(throws: HexConversionError.invalidDigit) {
            try HexUtil.byteArray(fromHex: "xy")
        }
    }

    @Test("Data initialization from hex")
    func testDataHexInitialization() {
        #expect(Data(hex: "deadbeef") == Data([0xde, 0xad, 0xbe, 0xef]))
        #expect(Data(hex: "0x1234") == Data([0x12, 0x34]))
        #expect(Data(hex: "xyz") == nil)
        #expect(Data(hex: "123") == nil)
    }

    @Test("Data to hex string conversion")
    func testDataToHexString() {
        #expect(Data([0xde, 0xad, 0xbe, 0xef]).toHexString(withPrefix: false) == "deadbeef")
        #expect(Data([0x00, 0xff]).toHexString(withPrefix: true) == "0x00ff")
    }

    @Test("String hex prefix handling")
    func testStringHexPrefixHandling() {
        #expect("0x1234".noHexPrefix == "1234")
        #expect("1234".noHexPrefix == "1234")

        #expect("1234".withHexPrefix == "0x1234")
        #expect("0x1234".withHexPrefix == "0x1234")
    }

    @Test("String to hex data conversion")
    func testStringToHexData() {
        #expect("deadbeef".hexData == Data([0xde, 0xad, 0xbe, 0xef]))
        #expect("0xdeadbeef".hexData == Data([0xde, 0xad, 0xbe, 0xef]))
        #expect("xyz".hexData == nil)
    }

    @Test("String value from hex")
    func testStringValueFromHex() {
        #expect("48656c6c6f".stringValue == "Hello")
        #expect("invalid".stringValue == "invalid")
    }
}
