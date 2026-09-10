import CrossmintCommonTypes
import Foundation
import Testing
import TestsUtils

@testable import Wallet

private func makeSolanaWallet(
    walletService: MockSmartWalletService,
    storage: MockDeviceSignerKeyStorage
) throws -> SolanaWallet {
    let baseModel: WalletApiModel = try GetFromFile.getModelFrom(
        fileName: "WalletSolanaEmail",
        bundle: Bundle.module
    )
    return try SolanaWallet(
        smartWalletService: walletService,
        signer: MockSigner(),
        baseModel: baseModel,
        solanaChain: .solana,
        onTransactionStart: nil,
        deviceSignerKeyStorage: storage
    )
}

@Suite("Wallet localDeviceSigner", .tags(.unit))
struct WalletLocalDeviceSignerTests {

    @Test func returnsTheDeviceLocatorWhenTheStorageHoldsTheWalletKey() async throws {
        let storage = MockDeviceSignerKeyStorage()
        let wallet = try makeSolanaWallet(walletService: MockSmartWalletService(), storage: storage)
        let publicKeyBase64 = try await storage.generateKey(address: wallet.address)

        #expect(await wallet.localDeviceSigner() == .device(publicKey: publicKeyBase64))
    }

    @Test func returnsNilWhenTheStorageHasNoKeyForTheWallet() async throws {
        let storage = MockDeviceSignerKeyStorage()
        let wallet = try makeSolanaWallet(walletService: MockSmartWalletService(), storage: storage)

        #expect(await wallet.localDeviceSigner() == nil)
    }
}
