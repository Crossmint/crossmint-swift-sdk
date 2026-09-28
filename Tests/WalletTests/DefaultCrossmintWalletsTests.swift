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

@Suite("Wallet Creation", .tags(.unit))
struct DefaultCrossmintWalletsTests {
    private let walletService = MockSmartWalletService()
    private let keyStorage = MockDeviceSignerKeyStorage()

    private func makeWallets() -> DefaultCrossmintWallets {
        DefaultCrossmintWallets(
            service: walletService,
            secureWalletStorage: StubSecureWalletStorage(),
            deviceSignerKeyStorage: keyStorage
        )
    }

    private func loadSolanaWalletFixture() throws -> Data {
        let url = try #require(Bundle.module.url(forResource: "WalletSolanaEmail", withExtension: "json"))
        return try Data(contentsOf: url)
    }

    @Test
    func includesDeviceSignerInSolanaCreateRequest() async throws {
        walletService.createWalletFixture = try loadSolanaWalletFixture()

        let wallet = try await makeWallets().createWallet(
            chain: Chain("solana"),
            recoveryMethods: [MockSigner()],
            options: WalletOptions(deviceSigner: true)
        )

        let entries = try #require(walletService.lastCreateWalletParams?.config.delegatedSigners)
        #expect(entries.count == 1)
        let publicKeyBase64 = try #require(await keyStorage.getKey(address: wallet.address))
        let expectedKey = try #require(DevicePublicKey(publicKeyBase64: publicKeyBase64))
        #expect(entries[0].signer == .device(publicKey: expectedKey, name: "Test Device"))
        #expect(walletService.createWalletCallCount == 1)
        #expect(await wallet.needsRecovery() == false)
        try await wallet.useSigner(.device)
        #expect(await wallet.selectedSigner?.locator == .device(publicKey: publicKeyBase64))
    }

    @Test
    func assignsAPendingDeviceKeyToAnExistingWalletOnGetWallet() async throws {
        let pendingKeyBase64 = try await keyStorage.generateKey(address: nil)
        walletService.getWalletFixture = try loadSolanaWalletFixture()
        walletService.getWalletSignerLocators = ["device:\(pendingKeyBase64)"]

        let wallet = try #require(
            try await makeWallets().getWallet(chain: Chain("solana"), options: WalletOptions(deviceSigner: true))
        )

        #expect(await keyStorage.getKey(address: wallet.address) == pendingKeyBase64)
        #expect(keyStorage.pendingKeys.isEmpty)
        #expect(await wallet.needsRecovery() == false)
    }

    @Test
    func retriesOnceWithoutDeviceSignerWhenProviderRejectsIt() async throws {
        walletService.createWalletFixture = try loadSolanaWalletFixture()
        walletService.createWalletErrors = [.deviceSignerNotSupported("not supported")]

        let wallet = try await makeWallets().createWallet(
            chain: Chain("solana"),
            recoveryMethods: [MockSigner()],
            options: WalletOptions(deviceSigner: true)
        )

        #expect(walletService.createWalletCallCount == 2)
        #expect(walletService.allCreateWalletParams[0].config.delegatedSigners != nil)
        #expect(walletService.allCreateWalletParams[1].config.delegatedSigners == nil)
        #expect(keyStorage.pendingKeys.isEmpty)
        #expect(keyStorage.keysByAddress.isEmpty)
        #expect(await wallet.needsRecovery() == false)
        await #expect {
            try await wallet.useSigner(.device)
        } throws: { error in
            guard case .deviceSignerNotSupported = error as? WalletError else { return false }
            return true
        }
        #expect(walletService.addSignerCallCount == 0)
    }

    @Test
    func surfacesOtherCreateErrorsWithoutRetrying() async throws {
        walletService.createWalletFixture = try loadSolanaWalletFixture()
        walletService.createWalletErrors = [.walletGeneric("backend down")]
        let wallets = makeWallets()

        await #expect {
            _ = try await wallets.createWallet(
                chain: Chain("solana"),
                recoveryMethods: [MockSigner()],
                options: WalletOptions(deviceSigner: true)
            )
        } throws: { error in
            guard case .walletGeneric = error as? WalletError else { return false }
            return true
        }
        #expect(walletService.createWalletCallCount == 1)
        #expect(keyStorage.deletePendingKeyCallCount == 1)
        #expect(keyStorage.pendingKeys.isEmpty)
    }

    @Test
    func discardsThePendingKeyWhenMappingItToTheWalletAddressFails() async throws {
        walletService.createWalletFixture = try loadSolanaWalletFixture()
        keyStorage.mapAddressToKeyError = .storageError(-1)

        let wallet = try await makeWallets().createWallet(
            chain: Chain("solana"),
            recoveryMethods: [MockSigner()],
            options: WalletOptions(deviceSigner: true)
        )

        #expect(keyStorage.deletePendingKeyCallCount == 1)
        #expect(keyStorage.pendingKeys.isEmpty)
        #expect(await keyStorage.getKey(address: wallet.address) == nil)
    }

    @Test
    func createsWalletWithoutDeviceSignerWhenKeyGenerationFails() async throws {
        walletService.createWalletFixture = try loadSolanaWalletFixture()
        keyStorage.generateKeyError = .keyGenerationFailed

        _ = try await makeWallets().createWallet(
            chain: Chain("solana"),
            recoveryMethods: [MockSigner()],
            options: WalletOptions(deviceSigner: true)
        )

        #expect(walletService.createWalletCallCount == 1)
        #expect(walletService.lastCreateWalletParams?.config.delegatedSigners == nil)
        #expect(walletService.addSignerCallCount == 0)
    }

    @Test
    func omitsDeviceSignerWhenNotRequested() async throws {
        walletService.createWalletFixture = try loadSolanaWalletFixture()

        let wallet = try await makeWallets().createWallet(
            chain: Chain("solana"),
            recoveryMethods: [MockSigner()],
            options: WalletOptions(deviceSigner: false)
        )

        #expect(walletService.lastCreateWalletParams?.config.delegatedSigners == nil)
        #expect(keyStorage.pendingKeys.isEmpty)
        #expect(keyStorage.keysByAddress.isEmpty)
        #expect(wallet.deviceSignerKeyStorage == nil)
    }
}

@Suite("Wallet Creation with a recovery signer list", .tags(.unit))
struct RecoverySignerListCreationTests {
    private let walletService = MockSmartWalletService()

    private func makeWallets() -> DefaultCrossmintWallets {
        DefaultCrossmintWallets(
            service: walletService,
            secureWalletStorage: StubSecureWalletStorage(),
            deviceSignerKeyStorage: MockDeviceSignerKeyStorage()
        )
    }

    private func loadFixture(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json"))
        return try Data(contentsOf: url)
    }

    @Test func sendsTheListUnderRecoveryAndNoAdminSigner() async throws {
        walletService.createWalletFixture = try loadFixture("WalletSolanaRecoveryMethods")
        let alice = MockSigner(email: "alice@example.com")
        let bob = MockSigner(email: "bob@example.com")

        _ = try await makeWallets().createWallet(chain: Chain("solana"), recoveryMethods: [alice, bob], options: nil)

        let config = try #require(walletService.lastCreateWalletParams?.config)
        #expect(config.adminSigner == nil)
        #expect(config.recoveryMethods?.count == 2)
    }

    @Test func keepsASingleRecoveryMethodAsIsOnAChainThatAcceptsAList() throws {
        let resolved = try RecoveryInput.single(MockSigner()).resolved(for: Chain("solana"))

        guard case .single = resolved else {
            Issue.record("A single recovery method must stay single on Solana")
            return
        }
    }

    @Test func sendsASingleRecoveryMethodUnderAdminSigner() async throws {
        let config = await RecoveryInput.single(MockSigner()).inputConfig(delegatedSigners: nil)

        #expect(config.adminSigner != nil)
        #expect(config.recoveryMethods == nil)
    }

    @Test func activatesTheApiFirstRecoverySignerNotTheCallerFirst() async throws {
        walletService.createWalletFixture = try loadFixture("WalletSolanaRecoveryMethods")
        let alice = MockSigner(email: "alice@example.com")
        let bob = MockSigner(email: "bob@example.com")

        let wallet = try await makeWallets().createWallet(
            chain: Chain("solana"),
            recoveryMethods: [bob, alice],
            options: nil
        )

        #expect(wallet.signer as? MockSigner === alice)
    }

    @Test func fallsBackToTheCallerFirstSignerWhenNoneMatchesTheApi() async throws {
        walletService.createWalletFixture = try loadFixture("WalletSolanaRecoveryMethods")
        let carol = MockSigner(email: "carol@example.com")
        let dave = MockSigner(email: "dave@example.com")

        let wallet = try await makeWallets().createWallet(
            chain: Chain("solana"),
            recoveryMethods: [carol, dave],
            options: nil
        )

        #expect(wallet.signer as? MockSigner === carol)
    }

    @Test func initializesEverySignerBeforeCreating() async throws {
        walletService.createWalletFixture = try loadFixture("WalletStellarRecoveryMethods")
        let alice = MockSigner(email: "alice@example.com")
        let bob = MockSigner(email: "bob@example.com")

        _ = try await makeWallets().createWallet(chain: Chain("stellar"), recoveryMethods: [alice, bob], options: nil)

        #expect(alice.initializeCallCount == 1)
        #expect(bob.initializeCallCount == 1)
    }

    @Test func rejectsAnEmptyList() async throws {
        let wallets = makeWallets()

        await #expect {
            _ = try await wallets.createWallet(chain: Chain("solana"), recoveryMethods: [any Signer](), options: nil)
        } throws: { error in
            guard case .recoveryConfigRejected(let code, _) = error as? WalletError else { return false }
            return code == .invalidConfig
        }
        #expect(walletService.createWalletCallCount == 0)
    }

    @Test func sendsAOneEntryListOnEVMUnderAdminSigner() async throws {
        walletService.createWalletFixture = try loadFixture("WalletEVMEmail")

        _ = try await makeWallets().createWallet(
            chain: Chain("base-sepolia"),
            recoveryMethods: [MockSigner(email: "alice@example.com")],
            options: nil
        )

        let config = try #require(walletService.lastCreateWalletParams?.config)
        #expect(config.adminSigner != nil)
        #expect(config.recoveryMethods == nil)
    }

    @Test func keepsAOneEntryListOnSolanaUnderRecoveryMethods() async throws {
        walletService.createWalletFixture = try loadFixture("WalletSolanaRecoveryMethods")

        _ = try await makeWallets().createWallet(
            chain: Chain("solana"),
            recoveryMethods: [MockSigner(email: "alice@example.com")],
            options: nil
        )

        let config = try #require(walletService.lastCreateWalletParams?.config)
        #expect(config.adminSigner == nil)
        #expect(config.recoveryMethods?.count == 1)
    }

    @Test func rejectsMoreThanOneSignerOnEVMBeforeCallingTheApi() async throws {
        let wallets = makeWallets()

        await #expect {
            _ = try await wallets.createWallet(
                chain: Chain("base-sepolia"),
                recoveryMethods: [MockSigner(email: "alice@example.com"), MockSigner(email: "bob@example.com")],
                options: nil
            )
        } throws: { error in
            guard case .recoveryConfigRejected(let code, _) = error as? WalletError else { return false }
            return code == .notSupportedOnChain
        }
        #expect(walletService.createWalletCallCount == 0)
    }

    private func sentRecoveryConfig() throws -> SentRecoveryConfig {
        let config = try #require(walletService.lastCreateWalletParams?.config)
        return try JSONDecoder().decode(SentRecoveryConfig.self, from: JSONEncoder().encode(config))
    }

    @Test(arguments: [
        ExternalWalletRecoveryCase(
            chain: "base-sepolia",
            fixture: "WalletEVMKeypair",
            address: "0x1234567890123456789012345678901234567890"
        ),
        ExternalWalletRecoveryCase(
            chain: "solana",
            fixture: "WalletSolanaKeypair",
            address: "EX2jMfAdfUKSqh7415jsTzGE1KMepXPeqM4vXyCpVXGc"
        ),
        ExternalWalletRecoveryCase(
            chain: "stellar",
            fixture: "WalletStellarExternalWallet",
            address: "GDQP2KPQGKIHYJGXNUIYOMHARUARCA7DJT5FO2FFOOKY3B2WSQHG4W37"
        )
    ])
    func sendsAnExternalWalletRecoverySigner(_ recovery: ExternalWalletRecoveryCase) async throws {
        walletService.createWalletFixture = try loadFixture(recovery.fixture)

        let wallet = try await makeWallets().createWallet(
            chain: Chain(recovery.chain),
            recoveryMethods: [ExternalWalletSigner(address: recovery.address, onSign: { _ in "" })],
            options: nil
        )

        #expect(try sentRecoveryConfig().methods == [.init(type: "external-wallet", address: recovery.address)])
        #expect(wallet.signer is ExternalWalletSigner)
    }
}

struct ExternalWalletRecoveryCase: Sendable, CustomTestStringConvertible {
    let chain: String
    let fixture: String
    let address: String

    var testDescription: String { chain }
}

private struct SentRecoveryConfig: Decodable {
    struct Method: Decodable, Equatable {
        let type: String
        let address: String?
    }

    let adminSigner: Method?
    let recoveryMethods: [Method]?

    var methods: [Method] { (adminSigner.map { [$0] } ?? []) + (recoveryMethods ?? []) }
}

@Suite("Wallet Loading", .tags(.unit))
struct WalletLoadingTests {
    private let walletService = MockSmartWalletService()

    private func makeWallets() -> DefaultCrossmintWallets {
        DefaultCrossmintWallets(
            service: walletService,
            secureWalletStorage: StubSecureWalletStorage(),
            deviceSignerKeyStorage: MockDeviceSignerKeyStorage()
        )
    }

    private func loadWallet(fixture: String, chain: String) async throws -> Wallet {
        let url = try #require(Bundle.module.url(forResource: fixture, withExtension: "json"))
        walletService.getWalletFixture = try Data(contentsOf: url)
        return try #require(try await makeWallets().getWallet(chain: Chain(chain), options: nil))
    }

    @Test func buildsAnEmailSignerFromTheApiRecoveryMethod() async throws {
        let wallet = try await loadWallet(fixture: "WalletSolanaEmail", chain: "solana")

        let signer = try #require(wallet.signer as? SolanaEmailSigner)
        #expect(signer.email == "solana.user@example.com")
    }

    @Test func buildsAPhoneSignerWithoutAChannelFromTheApiRecoveryMethod() async throws {
        let wallet = try await loadWallet(fixture: "WalletEVMPhone", chain: "base-sepolia")

        let signer = try #require(wallet.signer as? PhoneSigner)
        #expect(signer.phone == "+14155552671")
        #expect(signer.channel == nil)
    }

    @Test func buildsAnApiKeySignerFromTheApiRecoveryMethod() async throws {
        let wallet = try await loadWallet(fixture: "WalletEVMApiKey", chain: "base-sepolia")

        let signer = try #require(wallet.signer as? ApiKeySigner)
        #expect(signer.adminSigner.address == "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb")
    }

    @Test func leavesTheSignerUnsetForAPasskeyRecoveryMethod() async throws {
        let wallet = try await loadWallet(fixture: "WalletPasskey", chain: "base-sepolia")

        #expect(wallet.signer == nil)
    }

    @Test func leavesTheSignerUnsetForAnExternalWalletRecoveryMethod() async throws {
        let wallet = try await loadWallet(fixture: "WalletEVMKeypair", chain: "base-sepolia")

        #expect(wallet.signer == nil)
    }

    @Test func returnsNilWhenTheWalletDoesNotExist() async throws {
        walletService.getWalletError = .walletNotFound

        let wallet = try await makeWallets().getWallet(chain: Chain("solana"), options: nil)

        #expect(wallet == nil)
    }

    @Test func rejectsRegisteringASignerBeforeUseSignerWhenTheSdkCannotDriveTheRecoverySigner() async throws {
        let wallet = try await loadWallet(fixture: "WalletPasskey", chain: "base-sepolia")

        await #expect { try await wallet.addSigner(.email("alice@example.com")) } throws: { error in
            guard case .walletGeneric(let message) = error as? WalletError else { return false }
            return message.contains("useSigner")
        }
        #expect(walletService.addSignerCallCount == 0)
    }
}
