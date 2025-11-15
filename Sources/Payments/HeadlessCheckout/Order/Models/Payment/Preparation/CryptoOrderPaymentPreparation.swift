import CrossmintCommonTypes

public struct CryptoOrderPaymentPreparation: Codable, Sendable {
    public var chain: Chain?
    public var payerAddress: String?
    public var serializedTransaction: String?
}
