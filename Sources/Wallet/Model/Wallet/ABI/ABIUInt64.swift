import Foundation

public struct ABIUInt64: ABI.ABIType {
    private let uint: UInt64

    public init(uint: UInt64) {
        self.uint = uint
    }

    var data: Data {
        var uintBytes = withUnsafeBytes(of: uint.bigEndian, Array.init)
        uintBytes = Array(repeating: 0, count: 32 - uintBytes.count) + uintBytes
        return Data(uintBytes)
    }

    var typeName: String {
        "uint256"
    }
}
