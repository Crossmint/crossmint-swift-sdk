import Foundation
import Testing
import TestsUtils

@testable import Wallet

@Suite("WalletApiModel Tests")
struct WalletApiModelTest {
    @Test(
        "Parses an EVM Passkey Wallet"
    )
    func parsesEVMPasskeyWallet() async throws {
        let wallet: WalletApiModel = try GetFromFile.getModelFrom(
            fileName: "WalletPasskey",
            bundle: Bundle.module
        )

        #expect(wallet.config.recovery.type == .passkey)
    }

    @Test(
        "Parses an EVM keypair Wallet"
    )
    func parsesEVMKeypairWallet() async throws {
        let wallet: WalletApiModel = try GetFromFile.getModelFrom(
            fileName: "WalletEVMKeypair",
            bundle: Bundle.module
        )

        #expect(wallet.config.recovery.type == .externalWallet)
        let locator = wallet.config.recovery.toDomain.locator
        let expectedLocator = "external-wallet:0x1234567890123456789012345678901234567890"
        #expect(locator == expectedLocator)
    }

    @Test(
        "Parses a Solana keypair Wallet"
    )
    func parsesSolanaKeypairWallet() async throws {
        let wallet: WalletApiModel = try GetFromFile.getModelFrom(
            fileName: "WalletSolanaKeypair",
            bundle: Bundle.module
        )

        #expect(wallet.config.recovery.type == .externalWallet)
        let locator = wallet.config.recovery.toDomain.locator
        let expectedLocator = "external-wallet:EX2jMfAdfUKSqh7415jsTzGE1KMepXPeqM4vXyCpVXGc"
        #expect(locator == expectedLocator)
    }

    @Test(
        "Parses an EVM API key Wallet"
    )
    func parsesEVMApiKeyWallet() async throws {
        let wallet: WalletApiModel = try GetFromFile.getModelFrom(
            fileName: "WalletEVMApiKey",
            bundle: Bundle.module
        )

        #expect(wallet.config.recovery.type == .apiKey)
        let locator = wallet.config.recovery.toDomain.locator
        let expectedLocator = "api-key:0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb"
        #expect(locator == expectedLocator)
    }

    @Test(
        "Parses an EVM email Wallet"
    )
    func parsesEVMEmailWallet() async throws {
        let wallet: WalletApiModel = try GetFromFile.getModelFrom(
            fileName: "WalletEVMEmail",
            bundle: Bundle.module
        )

        #expect(wallet.config.recovery.type == .email)
        let locator = wallet.config.recovery.toDomain.locator
        let expectedLocator = "email:user@example.com"
        #expect(locator == expectedLocator)
    }

    @Test(
        "Parses a Solana email Wallet"
    )
    func parsesSolanaEmailWallet() async throws {
        let wallet: WalletApiModel = try GetFromFile.getModelFrom(
            fileName: "WalletSolanaEmail",
            bundle: Bundle.module
        )

        #expect(wallet.config.recovery.type == .email)
        let locator = wallet.config.recovery.toDomain.locator
        let expectedLocator = "email:solana.user@example.com"
        #expect(locator == expectedLocator)
    }

    @Test(
        "Parses an EVM phone Wallet"
    )
    func parsesEVMPhoneWallet() async throws {
        let wallet: WalletApiModel = try GetFromFile.getModelFrom(
            fileName: "WalletEVMPhone",
            bundle: Bundle.module
        )

        #expect(wallet.config.recovery.type == .phone)
        let locator = wallet.config.recovery.toDomain.locator
        let expectedLocator = "phone:+14155552671"
        #expect(locator == expectedLocator)
    }
}
