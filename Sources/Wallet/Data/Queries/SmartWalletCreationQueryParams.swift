import CrossmintCommonTypes

public protocol SmartWalletCreationQueryParams: Encodable, Sendable {
    var type: WalletType { get }
}
