import CrossmintCommonTypes
import CrossmintService
import DeviceSigner
import Foundation
import Security
import Testing
import TestsUtils

@testable import Wallet

@Suite("Wallet device signer over the in-memory key store", .tags(.unit))
struct WalletDeviceSignerFixtureTests {
    private let walletService = MockSmartWalletService()
    private let store = InMemoryKeychainItemStore()
    private let message = Data("approval-message".utf8).base64EncodedString()

    private func makeSolanaWallet(signerLocators: [String]? = nil) throws -> SolanaWallet {
        let fixtureUrl = try #require(Bundle.module.url(forResource: "WalletSolanaEmail", withExtension: "json"))
        let fixture = try Data(contentsOf: fixtureUrl)
        walletService.getWalletFixture = fixture
        walletService.getWalletSignerLocators = signerLocators
        let baseModel = try MockSmartWalletService.walletModel(from: fixture, signerLocators: signerLocators)
        return try SolanaWallet(
            smartWalletService: walletService,
            signer: MockSigner(),
            baseModel: baseModel,
            solanaChain: .solana,
            onTransactionStart: nil,
            deviceSignerKeyStorage: KeychainKeyStorage.inMemory(store)
        )
    }

    private func deviceApproval(
        of wallet: SolanaWallet,
        locator: SignerLocator
    ) async throws -> (String, SignRequestApi.Approval.DeviceSignature) {
        let request = try await wallet.makeSignRequest(for: locator.value, message: message)
        guard case let .device(signer, signature)? = request.approvals.first else {
            throw TestFailure.notADeviceApproval
        }
        return (signer, signature)
    }

    private enum TestFailure: Error { case notADeviceApproval }

    private func removalTransaction(status: String = "success") throws -> SolanaTransactionApiModel {
        let url = try #require(Bundle.module.url(forResource: "RemoveSignerTransactionSuccess", withExtension: "json"))
        var json = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any] ?? [:]
        json["status"] = status
        return try DefaultJSONCoder().decode(
            SolanaTransactionApiModel.self,
            from: JSONSerialization.data(withJSONObject: json)
        )
    }

    @Test func registersADeviceSignerAndSignsWithAVerifyingKey() async throws {
        let wallet = try makeSolanaWallet()

        try await wallet.recover()

        let locator = try #require(await wallet.localDeviceSigner())
        guard case .device(let publicKey) = locator else { Issue.record("expected a device locator"); return }
        #expect(walletService.addSignerCallCount == 1)
        let (signer, signature) = try await deviceApproval(of: wallet, locator: locator)
        #expect(signer == locator.value)
        #expect(P256SignatureCheck.verifies(
            r: signature.r, s: signature.s, publicKeyBase64: publicKey, messageBase64: message
        ))
    }

    @Test func recoversWhenTheRecordRemainsButTheKeyIsGone() async throws {
        let onboarded = try makeSolanaWallet()
        try await onboarded.recover()
        let oldLocator = try #require(await onboarded.localDeviceSigner())

        store.corrupt(tag: InMemoryKeychainItemStore.walletTag(address: onboarded.address))
        #expect(await onboarded.localDeviceSigner() == nil)

        let restored = try makeSolanaWallet(signerLocators: [oldLocator.value])
        #expect(await restored.needsRecovery() == true)

        try await restored.recover()

        let newLocator = try #require(await restored.localDeviceSigner())
        guard case .device(let newPublicKey) = newLocator else { Issue.record("expected a device locator"); return }
        #expect(newLocator != oldLocator)
        #expect(walletService.removeSignerCallCount == 0)
        let (_, signature) = try await deviceApproval(of: restored, locator: newLocator)
        #expect(P256SignatureCheck.verifies(
            r: signature.r, s: signature.s, publicKeyBase64: newPublicKey, messageBase64: message
        ))
    }

    @Test(arguments: [
        ["device:BAAA"],
        ["device:BAAA", "email:other.user@example.com"],
        ["device:BAAA", "device:BBBB"],
        ["device:BAAA", "device:BBBB", "device:BCCC"]
    ])
    func recoversOnADeviceWithNoKeyAndKeepsTheSignersOfOtherDevices(signers: [String]) async throws {
        let wallet = try makeSolanaWallet(signerLocators: signers)
        #expect(await wallet.needsRecovery())

        try await wallet.recover()

        #expect(await wallet.localDeviceSigner() != nil)
        #expect(await wallet.needsRecovery() == false)
        #expect(walletService.addSignerCallCount == 1)
        #expect(walletService.removeSignerCallCount == 0)
    }

    @Test(arguments: [[], ["device:BBBB"]])
    func keepsTheKeyThatWasUnreadableWhenTheWalletLoaded(otherDevices: [String]) async throws {
        let onboarded = try makeSolanaWallet()
        try await onboarded.recover()
        let locator = try #require(await onboarded.localDeviceSigner())

        store.locked = true
        let reloaded = try makeSolanaWallet(signerLocators: [locator.value] + otherDevices)
        #expect(await reloaded.needsRecovery())
        store.locked = false

        try await reloaded.recover()

        #expect(walletService.addSignerCallCount == 1)
        #expect(walletService.removeSignerCallCount == 0)
        #expect(await reloaded.needsRecovery() == false)
        #expect(await reloaded.localDeviceSigner() == locator)
    }

    @Test func replacesTheKeyOfARecoveryThatStoppedBeforeApproval() async throws {
        let abandonedKey = try await KeychainKeyStorage.inMemory(store).generateKey(address: nil)
        let abandoned = SignerLocator.device(publicKey: abandonedKey)
        let wallet = try makeSolanaWallet(signerLocators: ["device:BAAA", abandoned.value])
        walletService.getSignerResponses = [
            abandoned.value: AddDelegatedSignerResponse(
                chains: nil,
                transaction: RegistrationTransaction(id: "abandoned-transaction", status: "awaiting-approval")
            )
        ]
        walletService.fetchTransactionResult = try removalTransaction(status: "awaiting-approval")
        #expect(await wallet.needsRecovery())

        let pending = try await wallet.recover()

        let newLocator = try #require(await wallet.localDeviceSigner())
        #expect(pending == nil)
        #expect(newLocator != abandoned)
        #expect(walletService.addSignerCallCount == 1)
        #expect(await wallet.needsRecovery() == false)
        #expect(store.tags.count == 1)
    }

    @Test func waitsForARegistrationThatIsAlreadyApproved() async throws {
        let approvedKey = try await KeychainKeyStorage.inMemory(store).generateKey(address: nil)
        let approved = SignerLocator.device(publicKey: approvedKey)
        let wallet = try makeSolanaWallet(signerLocators: ["device:BAAA", approved.value])
        walletService.getSignerResponses = [
            approved.value: AddDelegatedSignerResponse(
                chains: nil,
                transaction: RegistrationTransaction(id: "approved-transaction", status: "pending")
            )
        ]
        walletService.fetchTransactionResult = try removalTransaction(status: "pending")

        let pending = try await wallet.recover()

        #expect(pending != nil)
        #expect(walletService.addSignerCallCount == 0)
        #expect(await wallet.needsRecovery())
        #expect(store.tags.count == 1)
    }

    @Test func marksTheWalletForRecoveryWhenTheTrustedKeyDies() async throws {
        let wallet = try makeSolanaWallet()
        try await wallet.recover()
        try await wallet.useSigner(.device)
        let oldLocator = try #require(await wallet.localDeviceSigner())
        _ = try await deviceApproval(of: wallet, locator: oldLocator)
        walletService.getWalletSignerLocators = [oldLocator.value]

        store.corrupt(tag: InMemoryKeychainItemStore.walletTag(address: wallet.address))

        await #expect(throws: SignerError.device(.keyNotFound)) {
            try await wallet.makeSignRequest(for: oldLocator.value, message: message)
        }
        #expect(await wallet.needsRecovery())

        try await wallet.recover()

        let newLocator = try #require(await wallet.localDeviceSigner())
        guard case .device(let newPublicKey) = newLocator else { Issue.record("expected a device locator"); return }
        #expect(newLocator != oldLocator)
        #expect(walletService.removeSignerCallCount == 0)
        #expect(await wallet.needsRecovery() == false)
        let (_, signature) = try await deviceApproval(of: wallet, locator: newLocator)
        #expect(P256SignatureCheck.verifies(
            r: signature.r, s: signature.s, publicKeyBase64: newPublicKey, messageBase64: message
        ))
    }

    @Test func keepsTheKeyThatWasOnlyUnreadable() async throws {
        let wallet = try makeSolanaWallet()
        try await wallet.recover()
        try await wallet.useSigner(.device)
        let locator = try #require(await wallet.localDeviceSigner())
        guard case .device(let publicKey) = locator else { Issue.record("expected a device locator"); return }

        store.locked = true
        await #expect(throws: SignerError.device(.keyNotFound)) {
            try await wallet.makeSignRequest(for: locator.value, message: message)
        }
        #expect(await wallet.needsRecovery())
        store.locked = false

        try await wallet.recover()

        #expect(walletService.addSignerCallCount == 1)
        #expect(await wallet.needsRecovery() == false)
        #expect(await wallet.localDeviceSigner() == locator)
        let (_, signature) = try await deviceApproval(of: wallet, locator: locator)
        #expect(P256SignatureCheck.verifies(
            r: signature.r, s: signature.s, publicKeyBase64: publicKey, messageBase64: message
        ))
    }

    @Test func removingTheDeviceSignerDeletesTheLocalKey() async throws {
        let wallet = try makeSolanaWallet()
        try await wallet.recover()
        let locator = try #require(await wallet.localDeviceSigner())
        walletService.removeSignerResult = try removalTransaction()

        _ = try await wallet.removeSigner(locator: locator)

        #expect(store.tags.isEmpty)
        #expect(await wallet.localDeviceSigner() == nil)
    }

    @Test func keepsTheLocalKeyWhenTheRemovalFailsOnChain() async throws {
        let wallet = try makeSolanaWallet()
        try await wallet.recover()
        let locator = try #require(await wallet.localDeviceSigner())
        walletService.removeSignerResult = try removalTransaction(status: "failed")

        _ = try await wallet.removeSigner(locator: locator)

        #expect(store.tags.count == 1)
        #expect(await wallet.localDeviceSigner() == locator)
    }

    @Test func reportsTheRemovalWhenTheLocalKeyCannotBeDeleted() async throws {
        let wallet = try makeSolanaWallet()
        try await wallet.recover()
        let locator = try #require(await wallet.localDeviceSigner())
        walletService.removeSignerResult = try removalTransaction()
        store.deleteError = .storageError(errSecInteractionNotAllowed)

        _ = try await wallet.removeSigner(locator: locator)

        #expect(store.tags.count == 1)
        #expect(await wallet.localDeviceSigner() == locator)
    }

    @Test func keepsTheLocalKeyWhenAnotherDeviceSignerIsRemoved() async throws {
        let wallet = try makeSolanaWallet()
        try await wallet.recover()
        walletService.removeSignerResult = try removalTransaction()

        _ = try await wallet.removeSigner(locator: .device(publicKey: "BAAA"))

        #expect(store.tags.count == 1)
        #expect(await wallet.localDeviceSigner() != nil)
    }
}
