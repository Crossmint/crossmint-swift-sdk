import Foundation
import Testing
import TestsUtils

@testable import Wallet

struct SmartWalletConfigResponseTest {
    @Test("EOA wallet")
    func willParseEOAWallet() async throws {
        let response: SmartWalletConfigResponse = try GetFromFile.getModelFrom(
            fileName: "SmartWalletConfigResponseEOA",
            bundle: Bundle.module
        )

        #expect(response.signers.first?.signerData.toDomain.type == .eoa)
    }

    @Test("Passkeys wallet")
    func willParsePasskeysWallet() async throws {
        let response: SmartWalletConfigResponse = try GetFromFile.getModelFrom(
            fileName: "SmartWalletConfigResponsePasskeys",
            bundle: Bundle.module
        )

        #expect(response.signers.first?.signerData.toDomain.type == .passkeys)
    }
}
