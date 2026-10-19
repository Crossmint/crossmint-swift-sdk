import CrossmintCommonTypes
import Foundation
import Testing
import TestsUtils
import Web

@testable import Wallet

@Suite("Wallet email signer over the scripted frame", .tags(.unit), .serialized)
@MainActor
struct WalletEmailSignerFrameTests {
    private let walletService = MockSmartWalletService()
    private let email = "user@example.com"
    private let message = "0x52769994aa43c041dad4d211d584bef75e03b318dc8d34a449f815aeb50b99c8"

    private func makeWallets() -> DefaultCrossmintWallets {
        DefaultCrossmintWallets(
            service: walletService,
            secureWalletStorage: MockSecureWalletStorage(),
            deviceSignerKeyStorage: MockDeviceSignerKeyStorage()
        )
    }

    private func emailWalletFixture() throws -> Data {
        let url = try #require(Bundle.module.url(forResource: "WalletEVMEmail", withExtension: "json"))
        return try Data(contentsOf: url)
    }

    private func createWallet(signingWith tee: CrossmintTEE) async throws -> Wallet {
        walletService.createWalletFixture = try emailWalletFixture()
        return try await makeWallets().createWallet(
            chain: Chain("base-sepolia"),
            recoveryMethods: [EVMEmailSigner(email: email, crossmintTEE: tee)],
            options: nil
        )
    }

    private func keypairSignature(of request: SignRequestApi) throws -> String {
        guard case let .keypair(signer, signature)? = request.approvals.first else {
            throw TestFailure.notAKeypairApproval
        }
        #expect(signer == "email:\(email)")
        return signature
    }

    private enum TestFailure: Error { case notAKeypairApproval }

    @Test func onboardsANewDeviceThenSignsWithTheFrameKey() async throws {
        let fixture = try SignerFrameFixture()
        await fixture.authenticate()
        fixture.scriptHandshake()
        fixture.scriptNewDevice()
        fixture.scriptSigning()
        let wallet = try await createWallet(signingWith: fixture.tee)

        let signing = Task { try await wallet.makeSignRequest(for: "email:\(email)", message: message) }
        await fixture.waitForOTPRequired()
        fixture.tee.provideOTP("123456")

        let signature = try keypairSignature(of: try await signing.value)
        #expect(fixture.key.verifies(signatureHex: signature, hexBytes: message))
        #expect(fixture.lastOtpSubmitted() == "123456")
        #expect(fixture.tee.isOTPRequired == false)
    }

    @Test func buildsTheSignerFromTheInstalledFrameWhenLoadingAWallet() async throws {
        let fixture = try SignerFrameFixture()
        await fixture.authenticate()
        fixture.scriptHandshake()
        fixture.scriptReadyDevice()
        fixture.scriptSigning()
        CrossmintTEE.shared = fixture.tee
        defer { CrossmintTEE.shared = nil }
        walletService.getWalletFixture = try emailWalletFixture()
        let wallet = try #require(try await makeWallets().getWallet(chain: Chain("base-sepolia"), options: nil))

        let request = try await wallet.makeSignRequest(for: "email:\(email)", message: message)
        let signature = try keypairSignature(of: request)

        #expect(fixture.key.verifies(signatureHex: signature, hexBytes: message))
    }

    @Test func reportsCancellationWhenTheUserAbandonsTheOtp() async throws {
        let fixture = try SignerFrameFixture()
        await fixture.authenticate()
        fixture.scriptHandshake()
        fixture.scriptNewDevice()
        let wallet = try await createWallet(signingWith: fixture.tee)

        let signing = Task { try await wallet.makeSignRequest(for: "email:\(email)", message: message) }
        await fixture.waitForOTPRequired()
        fixture.tee.cancelOTP()

        await #expect(throws: SignerError.cancelled) { try await signing.value }
    }

    @Test func retriesTheHandshakeThreeTimesPerAttemptWhenTheFrameNeverAnswers() async throws {
        let fixture = try SignerFrameFixture()
        await fixture.authenticate()
        fixture.scriptReadyDevice()
        fixture.scriptSigning()
        let wallet = try await createWallet(signingWith: fixture.tee)
        #expect(fixture.handshakeCount() == 3)

        await #expect(throws: SignerError.signingFailed) {
            try await wallet.makeSignRequest(for: "email:\(email)", message: message)
        }
        #expect(fixture.handshakeCount() == 6)
    }

    @Test(arguments: ["storage", "ready"])
    func reportsSigningFailedWhenTheFrameCannotReportAReadySigner(failure: String) async throws {
        let fixture = try SignerFrameFixture()
        await fixture.authenticate()
        fixture.scriptHandshake()
        if failure == "storage" { fixture.scriptStorageUnavailable() } else { fixture.scriptReadyNeverSent() }
        let wallet = try await createWallet(signingWith: fixture.tee)

        await #expect(throws: SignerError.signingFailed) {
            try await wallet.makeSignRequest(for: "email:\(email)", message: message)
        }
    }

    @Test func recoversWhenTheFrameProcessIsTerminated() async throws {
        let fixture = try SignerFrameFixture()
        await fixture.authenticate()
        fixture.scriptHandshake()
        fixture.scriptReadyDevice()
        fixture.scriptSigning()
        let wallet = try await createWallet(signingWith: fixture.tee)
        let handshakesBefore = fixture.handshakeCount()

        fixture.terminateFrame()
        let request = try await wallet.makeSignRequest(for: "email:\(email)", message: message)
        let signature = try keypairSignature(of: request)

        #expect(fixture.key.verifies(signatureHex: signature, hexBytes: message))
        #expect(fixture.handshakeCount() > handshakesBefore)
    }
}
