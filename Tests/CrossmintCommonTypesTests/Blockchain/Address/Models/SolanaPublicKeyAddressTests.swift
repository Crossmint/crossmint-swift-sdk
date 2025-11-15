import Testing

@testable import CrossmintCommonTypes

@Suite("Solana Address and PublicKey tests")
struct SolanaPublicKeyAddressTests {
    @Test("Should parse a valid Solana public address")
    func shouldParseValidSolanaPublicAddress() throws {
        let address = "4xDsmeTWPNjgSVSS1VTfzFq3iHZhp77ffPkAmkZkdu71"
        let solanaAddress = try SolanaAddress(address: address)
        #expect(solanaAddress.address == address)
    }

    @Test("Should parse a valid Solana public key")
    func shouldParseValidSolanaPublicKey() throws {
        let address = "4xDsmeTWPNjgSVSS1VTfzFq3iHZhp77ffPkAmkZkdu71"
        let expectedKey = "3ab8903fb735cab1c67c59af4857edf61b0af832a50a7c59e321919e0ec8a9bc"
        let solanaAddress = try SolanaAddress(address: address)
        #expect(solanaAddress.publicKey == expectedKey)
    }
}
