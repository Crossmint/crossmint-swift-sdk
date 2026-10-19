import CrossmintCommonTypes
import Testing
@testable import Wallet

@Suite("Integration: delegated signer")
struct DelegatedSignerFlowTests {
    @Test func registersSignsWithAndRemovesAnExternalWalletSigner() async throws {
        let session = try await CryptoWalletSession.start()
        let recipient = try await CryptoWalletSession.start()
        let wallet = try await session.wallets().createWallet(
            chain: IntegrationEnvironment.chain, recovery: session.keypair, options: nil
        )
        let delegate = try EVMKeyPairSigner()
        try await delegate.initialize(nil)
        let delegateAddress = await delegate.evmAddress.address
        let delegateConfig = SignerConfig.externalWallet(delegateAddress) { message in
            try await delegate.sign(message: message)
        }

        try await wallet.addSigner(delegateConfig)
        try await wallet.fund(token: .usdxm, amount: 5)
        try await wallet.useSigner(delegateConfig)
        let transfer = try await wallet.send(recipient.address, IntegrationEnvironment.tokenLocator, 1)
        let registered = try await wallet.signers().map(\.locator)
        _ = try await wallet.removeSigner(locator: .externalWallet(address: delegateAddress))
        let remaining = try await wallet.signers().map(\.locator)

        #expect(transfer.hash.hasPrefix("0x"))
        #expect(registered.contains(.externalWallet(address: delegateAddress)))
        #expect(!remaining.contains(.externalWallet(address: delegateAddress)))
    }
}
