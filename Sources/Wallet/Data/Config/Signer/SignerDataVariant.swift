enum SignerDataVariant {
    case eoa(EOASignerData)
    case passkey(PasskeySignerConfigData)

    var signerData: SignerDataProtocol {
        switch self {
        case .eoa(let data):
            return data
        case .passkey(let data):
            return data
        }
    }
}
