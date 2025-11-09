enum SignerDataType: String, Codable {
    case eoa
    case passkeys

    var locator: String {
        switch self {
        case .eoa:
            "evm-keypair"
        case .passkeys:
            "not implemented yet"
        }
    }

    var toDomain: AccountWalletConfig.Signer.Data.SignerType {
        switch self {
        case .eoa:
            return .eoa
        case .passkeys:
            return .passkeys
        }
    }
}
