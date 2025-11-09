import Foundation
import Testing
import TestsUtils

@testable import Wallet

struct WalletApiModelTest {
    @Test(
        "Will parse an EVM Passkey Wallet"
    )
    func willParseEVMPasskeyWallet() async throws {
        let wallet: WalletApiModel = try GetFromFile.getModelFrom(
            fileName: "WalletPasskey",
            bundle: Bundle.module
        )

        #expect(wallet.config.adminSigner.type == .passkey)
    }

    @Test(
        "Will parse an EVM keypair Wallet"
    )
    func willParseEVMKeypairWallet() async throws {
        let wallet: WalletApiModel = try GetFromFile.getModelFrom(
            fileName: "WalletEVMKeypair",
            bundle: Bundle.module
        )

        #expect(wallet.config.adminSigner.type == .externalWallet)
        let locator = wallet.config.adminSigner.toDomain.locator
        let expectedLocator = "external-wallet:0x1234567890123456789012345678901234567890"
        #expect(locator == expectedLocator)
    }

    @Test(
        "Will parse a Solana keypair Wallet"
    )
    func willParseSolanaKeypairWallet() async throws {
        let wallet: WalletApiModel = try GetFromFile.getModelFrom(
            fileName: "WalletSolanaKeypair",
            bundle: Bundle.module
        )

        #expect(wallet.config.adminSigner.type == .externalWallet)
        let locator = wallet.config.adminSigner.toDomain.locator
        let expectedLocator = "external-wallet:EX2jMfAdfUKSqh7415jsTzGE1KMepXPeqM4vXyCpVXGc"
        #expect(locator == expectedLocator)
    }

    @Test(
        "Will parse an EVM API key Wallet"
    )
    func willParseEVMApiKeyWallet() async throws {
        let wallet: WalletApiModel = try GetFromFile.getModelFrom(
            fileName: "WalletEVMApiKey",
            bundle: Bundle.module
        )

        #expect(wallet.config.adminSigner.type == .apiKey)
        let locator = wallet.config.adminSigner.toDomain.locator
        // New ApiKeySignerData uses fixed locatorId
        let expectedLocator = "api-key:api-key"
        #expect(locator == expectedLocator)
    }

    @Test(
        "Will parse an EVM email Wallet"
    )
    func willParseEVMEmailWallet() async throws {
        let wallet: WalletApiModel = try GetFromFile.getModelFrom(
            fileName: "WalletEVMEmail",
            bundle: Bundle.module
        )

        #expect(wallet.config.adminSigner.type == .email)
        let locator = wallet.config.adminSigner.toDomain.locator
        let expectedLocator = "email:user@example.com"
        #expect(locator == expectedLocator)
    }

    @Test(
        "Will parse a Solana email Wallet"
    )
    func willParseSolanaEmailWallet() async throws {
        let wallet: WalletApiModel = try GetFromFile.getModelFrom(
            fileName: "WalletSolanaEmail",
            bundle: Bundle.module
        )

        #expect(wallet.config.adminSigner.type == .email)
        let locator = wallet.config.adminSigner.toDomain.locator
        let expectedLocator = "email:solana.user@example.com"
        #expect(locator == expectedLocator)
    }

    @Test(
        "Will parse an EVM phone Wallet"
    )
    func willParseEVMPhoneWallet() async throws {
        let wallet: WalletApiModel = try GetFromFile.getModelFrom(
            fileName: "WalletEVMPhone",
            bundle: Bundle.module
        )

        #expect(wallet.config.adminSigner.type == .phone)
        let locator = wallet.config.adminSigner.toDomain.locator
        let expectedLocator = "phone:+14155552671"
        #expect(locator == expectedLocator)
    }
}
