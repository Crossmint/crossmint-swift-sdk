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
        let expectedLocator = delegate.adminSigner.locator.lowercased()
        let signers = try await wallet.signers()
        let match = signers.first { $0.locator.value.lowercased() == expectedLocator }
        let registered = try #require(match)
        guard case .externalWallet(let registeredAddress) = registered.locator else {
            Issue.record("registered as \(registered.locator.value)")
            return
        }
        try await Funding.fund(wallet, usdxm: 5)
        let selected = SignerConfig.externalWallet(registeredAddress) { message in
            try await delegate.sign(message: message)
        }
        try await wallet.useSigner(selected)
        let transfer: TransactionSummary
        do {
            transfer = try await wallet.send(recipient.address, IntegrationEnvironment.EVM_USDXM, 1)
        } catch {
            if case .transactionSigningFailed(let inner) = error {
                Issue.record("signing with \(registered.locator.value) (status \(registered.status)) failed: \(inner)")
                return
            }
            throw error
        }
        try await wallet.useSigner(session.signer.config)
        _ = try await wallet.removeSigner(locator: registered.locator)
        let remaining = try await wallet.signers().map(\.locator)

        #expect(transfer.hash.hasPrefix("0x"))
        #expect(registered.status == .active)
        #expect(!remaining.contains(registered.locator))
    }
}
