import Testing

@testable import CrossmintCommonTypes

struct PublicAddressTest {
    @Test("Should parse a valid EVM public address")
    func shouldParseValidEVMPublicAddress() throws {
        let address = "0x3416cF6C708Da44DB2624D63ea0AAef7113527C6"
        let evmAddress = try EVMAddress(address: address)
        #expect(evmAddress.address == address)
    }
}
