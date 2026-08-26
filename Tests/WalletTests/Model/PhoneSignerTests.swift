import CrossmintCommonTypes
import Foundation
import Testing

@testable import Wallet

@Suite("Phone Signer", .tags(.unit))
struct PhoneSignerTests {
    private func makeSigner(chainType: ChainType, channel: OTPDeliveryChannel? = nil) -> PhoneSigner {
        PhoneSigner(phone: "+15551234567", channel: channel, chainType: chainType, crossmintTEE: nil)
    }

    @Test func usesSecp256k1AndHexOnEVM() async {
        let signer = makeSigner(chainType: .evm)
        #expect(await signer.keyType == "secp256k1")
        #expect(await signer.encoding == "hex")
    }

    @Test func usesEd25519AndBase58OnSolana() async {
        let signer = makeSigner(chainType: .solana)
        #expect(await signer.keyType == "ed25519")
        #expect(await signer.encoding == "base58")
    }

    @Test func usesEd25519AndBase64OnStellar() async {
        let signer = makeSigner(chainType: .stellar)
        #expect(await signer.keyType == "ed25519")
        #expect(await signer.encoding == "base64")
    }

    @Test func stripsTheHexPrefixOnEVMOnly() {
        #expect(makeSigner(chainType: .evm).processMessage("0xabc") == "abc")
        #expect(makeSigner(chainType: .solana).processMessage("0xabc") == "0xabc")
    }

    @Test func reportsAPhoneSignerType() {
        #expect(makeSigner(chainType: .evm).signerType == .phone)
    }

    @Test func buildsAPhoneLocatorForApprovals() async throws {
        let signer = makeSigner(chainType: .evm, channel: .whatsapp)
        let approvals = try await signer.approvals(withSignature: "0xsignature")
        #expect(await signer.adminSigner.locator == "phone:+15551234567")
        #expect(approvals.count == 1)
    }

    @Test func reportsTheRequestedChannel() {
        #expect(makeSigner(chainType: .evm, channel: .whatsapp).channel == .whatsapp)
        #expect(makeSigner(chainType: .evm).channel == nil)
    }
}
