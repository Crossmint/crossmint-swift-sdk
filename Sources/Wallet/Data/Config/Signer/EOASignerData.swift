struct EOASignerData: Codable, SignerDataProtocol {
    let type: SignerDataType
    let eoaAddress: String

    var locator: String {
        "\(type.locator):\(eoaAddress)"
    }

    var toDomain: AccountWalletConfig.Signer.Data {
        AccountWalletConfig.Signer.Data(
            type: type.toDomain,
            eoaAddress: eoaAddress,
            pubKeyX: nil,
            pubKeyY: nil,
            entryPoint: nil,
            validatorContractVersion: nil,
            validatorAddress: nil,
            authenticatorIdHash: nil,
            authenticatorId: nil,
            passkeyName: nil,
            domain: nil,
            passkeyServerUrl: nil
        )
    }
}
