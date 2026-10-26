import Foundation
import Testing

@Suite("Base58")
struct Base58Tests {
    @Test(arguments: [
        ("", ""), ("00", "1"), ("0000ff", "115Q"), ("61", "2g"), ("626262", "a3gV"),
        ("00010966776006953d5567439e5e39f86a0d273beed61967f6", "16UwLL9Risc3QfPqBUvKofHmBQ7wMtjvM")
    ])
    func roundTrips(hex: String, base58: String) throws {
        let data = Data(stride(from: 0, to: hex.count, by: 2).compactMap {
            UInt8(hex[hex.index(hex.startIndex, offsetBy: $0)..<hex.index(hex.startIndex, offsetBy: $0 + 2)], radix: 16)
        })
        #expect(Base58.encode(data) == base58)
        #expect(Base58.decode(base58) == data)
    }

    @Test func rejectsACharacterOutsideTheAlphabet() {
        #expect(Base58.decode("0OIl") == nil)
    }
}
