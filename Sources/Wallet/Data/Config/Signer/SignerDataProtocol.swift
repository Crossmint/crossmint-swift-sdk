protocol SignerDataProtocol {
    var type: SignerDataType { get }
    var toDomain: AccountWalletConfig.Signer.Data { get }
    var locator: String { get }
}
