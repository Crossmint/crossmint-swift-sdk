import Foundation

public struct ABIAddress: ABI.ABIType {
    private let address: String

    public init(address: String) {
        self.address = address
    }

    var data: Data {
        get throws (ABI.Error) {
            let clean = address.lowercased().replacingOccurrences(of: "0x", with: "")
            guard let addressData = clean.hexData, addressData.count == 20 else {
                throw .invalidAddress(address)
            }
            return Self.padTo32Bytes(addressData)
        }
    }

    var typeName: String {
        "address"
    }

    private static func padTo32Bytes(_ input: Data) -> Data {
        return Data(repeating: 0, count: 32 - input.count) + input
    }
}
