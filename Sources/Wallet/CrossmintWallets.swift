import CrossmintCommonTypes
import DeviceSigner

public protocol CrossmintWallets: Sendable {
    func getOrCreateWallet<C: ChainWithSigners>(
        chain: C,
        recovery: C.SpecificSigner,
        options: WalletOptions?
    ) async throws(WalletError) -> Wallet
}

extension CrossmintWallets {
    public func getOrCreateWallet<C: ChainWithSigners>(
        chain: C,
        recovery: C.SpecificSigner
    ) async throws(WalletError) -> Wallet {
        try await getOrCreateWallet(chain: chain, recovery: recovery, options: nil)
    }
}

public struct WalletOptions {
    let experimentalCallbacks: ExperimentalCallbacks?
    public let deviceSigner: DeviceSignerOptions?

    public init(deviceSigner: DeviceSignerOptions? = nil) {
        self.experimentalCallbacks = nil
        self.deviceSigner = deviceSigner
    }

    init(deviceSigner: DeviceSignerOptions? = nil, experimentalCallbacks: ExperimentalCallbacks?) {
        self.deviceSigner = deviceSigner
        self.experimentalCallbacks = experimentalCallbacks
    }
}

protocol ExperimentalCallbacks {
    func onWalletCreationStart()
    func onTransactionStart()
}
