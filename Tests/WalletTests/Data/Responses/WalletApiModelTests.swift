import CrossmintService
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

        #expect(wallet.config.recovery.type == .passkey)
    }

    @Test(
        "Will parse an EVM keypair Wallet"
    )
    func willParseEVMKeypairWallet() async throws {
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
        "Will parse a Solana keypair Wallet"
    )
    func willParseSolanaKeypairWallet() async throws {
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
        "Will parse an EVM API key Wallet"
    )
    func willParseEVMApiKeyWallet() async throws {
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
        "Will parse an EVM email Wallet"
    )
    func willParseEVMEmailWallet() async throws {
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
        "Will parse a Solana email Wallet"
    )
    func willParseSolanaEmailWallet() async throws {
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
        "Will parse an EVM phone Wallet"
    )
    func willParseEVMPhoneWallet() async throws {
        let wallet: WalletApiModel = try GetFromFile.getModelFrom(
            fileName: "WalletEVMPhone",
            bundle: Bundle.module
        )

        #expect(wallet.config.recovery.type == .phone)
        let locator = wallet.config.recovery.toDomain.locator
        let expectedLocator = "phone:+14155552671"
        #expect(locator == expectedLocator)
    }

    @Test(
        "Will parse every recovery signer of a Solana wallet"
    )
    func willParseSolanaRecoveryList() async throws {
        let wallet: WalletApiModel = try GetFromFile.getModelFrom(
            fileName: "WalletSolanaRecoveryMethods",
            bundle: Bundle.module
        )

        #expect(wallet.config.recoveryMethods?.map(\.type) == [.email, .phone, .externalWallet])
        #expect(wallet.config.recovery.type == .email)
        #expect(wallet.config.toDomain.recoveryMethods.map(\.locator) == [
            "email:alice@example.com",
            "phone:+14155552671",
            "external-wallet:GbA2NZfpAnRVM2G2BG29qooqsYbdV5c2WVFymJ8MMir7"
        ])
    }

    @Test(
        "Will parse every recovery signer of a Stellar wallet"
    )
    func willParseStellarRecoveryList() async throws {
        let wallet: WalletApiModel = try GetFromFile.getModelFrom(
            fileName: "WalletStellarRecoveryMethods",
            bundle: Bundle.module
        )

        #expect(wallet.config.recoveryMethods?.count == 2)
        #expect(wallet.config.toDomain.recovery.locator == "email:alice@example.com")
    }

    @Test(
        "Will fall back to the admin signer when the recovery list is absent"
    )
    func willFallBackToAdminSigner() async throws {
        let wallet: WalletApiModel = try GetFromFile.getModelFrom(
            fileName: "WalletEVMEmail",
            bundle: Bundle.module
        )

        #expect(wallet.config.recoveryMethods == nil)
        #expect(wallet.config.toDomain.recoveryMethods.map(\.locator) == ["email:user@example.com"])
    }

    @Test(
        "Will fall back to the admin signer when the recovery list is empty"
    )
    func willFallBackToAdminSignerOnEmptyList() async throws {
        let url = try #require(Bundle.module.url(forResource: "WalletEVMEmail", withExtension: "json"))
        let fixture = try String(contentsOf: url, encoding: .utf8)
        let json = fixture.replacingOccurrences(of: "\"adminSigner\"", with: "\"recovery\": [], \"adminSigner\"")

        let wallet = try DefaultJSONCoder().decode(WalletApiModel.self, from: Data(json.utf8))

        #expect(wallet.config.recoveryMethods?.isEmpty == true)
        #expect(wallet.config.toDomain.recoveryMethods.map(\.locator) == ["email:user@example.com"])
    }
}
