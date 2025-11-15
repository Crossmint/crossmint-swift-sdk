import Testing
@testable import Wallet

struct ERC20EncoderTest {
    @Test("Valid input")
    func testValidInput() async throws {
        let encoded = try ERC20Encoder.encode(
            functionName: "mintTo",
            arguments: [.address("0x2180b6038525359a658b460a00D89202FB421026")]
        )
        #expect(encoded == "0x755edd170000000000000000000000002180b6038525359a658b460a00d89202fb421026")
    }

    @Test("Invalid address")
    func testTransferInvalidAddress() async throws {
        #expect(throws: ERC20Encoder.Error.invalidAddress(address: "0x123")) {
            try ERC20Encoder.encode(
                functionName: "transfer",
                arguments: [.address("0x123"), .uint64(1000)]
            )
        }
    }
}
