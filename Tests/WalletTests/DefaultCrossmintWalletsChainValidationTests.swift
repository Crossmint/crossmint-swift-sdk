import CrossmintCommonTypes
import Foundation
import SecureStorage
import Testing
import TestsUtils

@testable import Wallet

private final class StubSecureWalletStorage: SecureWalletStorage, @unchecked Sendable {
    func savePrivateKey(_ privateKey: String, forEmail email: String) {}
    func getPrivateKey(forEmail email: String) -> String? { nil }
}

@Suite("Wallet chain validation", .tags(.unit))
struct DefaultCrossmintWalletsChainValidationTests {
    private let walletService = MockSmartWalletService()

    private func makeWallets() -> DefaultCrossmintWallets {
        DefaultCrossmintWallets(
            service: walletService,
            secureWalletStorage: StubSecureWalletStorage(),
            deviceSignerKeyStorage: MockDeviceSignerKeyStorage()
        )
    }

    @Test(arguments: ["bitcoin", "", "base_sepolia"])
    func rejectsAnUnknownChainBeforeCallingTheApi(chain: String) async throws {
        let wallets = makeWallets()

        await #expect {
            _ = try await wallets.createWallet(
                chain: Chain(chain),
                recoveryMethods: [MockSigner(email: "alice@example.com")],
                options: nil
            )
        } throws: { error in
            guard case .invalidChain = error as? WalletError else { return false }
            return true
        }
        #expect(walletService.createWalletCallCount == 0)
    }
}
