import CrossmintCommonTypes
import Testing
@testable import Wallet

@Suite("Integration: delegated signer")
struct DelegatedSignerFlowTests {
    @Test func registersSignsWithAndRemovesAnExternalWalletSigner() async throws {
        let session = try await SessionPool.shared.primary()
        let recipient = try await SessionPool.shared.secondary()
        let wallet = try await SessionPool.shared.evmWallet(of: session)
        let delegate = try await EVMPersonalSigner.make()

        try await wallet.addSigner(delegate.config)
        let registered = try #require(try await wallet.signers().first { signer in
            signer.locator.value.lowercased() == delegate.adminSigner.locator.lowercased()
        })
        guard case .externalWallet(let registeredAddress) = registered.locator else {
            Issue.record("registered as \(registered.locator.value)")
            return
        }
        try await wallet.fund(token: .usdxm, amount: 5)
        try await wallet.useSigner(.externalWallet(registeredAddress) { message in try await delegate.sign(message: message) })
        let transfer: TransactionSummary
        do {
            transfer = try await wallet.send(recipient.address, IntegrationEnvironment.EVM_USDXM, 1)
        } catch TransactionError.transactionSigningFailed(let inner) {
            Issue.record("signing with \(registered.locator.value) (status \(registered.status)) failed: \(inner)")
            return
        }
        _ = try await wallet.removeSigner(locator: registered.locator)
        let remaining = try await wallet.signers().map(\.locator)

        #expect(transfer.hash.hasPrefix("0x"))
        #expect(registered.status == .active)
        #expect(!remaining.contains(registered.locator))
    }
}
