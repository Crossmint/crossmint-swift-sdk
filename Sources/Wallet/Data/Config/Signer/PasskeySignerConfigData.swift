import Foundation

struct PasskeySignerConfigData: Codable, SignerDataProtocol {
    let type: SignerDataType
    let pubKeyX: String
    let pubKeyY: String
    let entryPoint: String
    let validatorContractVersion: String
    let validatorAddress: String
    let authenticatorIdHash: String
    let authenticatorId: String
    let passkeyName: String
    let domain: String
    let passkeyServerUrl: String

    var locator: String {
        "not implemented yet"
    }

    var toDomain: AccountWalletConfig.Signer.Data {
        AccountWalletConfig.Signer.Data(
            type: type.toDomain,
            eoaAddress: nil,
            pubKeyX: pubKeyX,
            pubKeyY: pubKeyY,
            entryPoint: entryPoint,
            validatorContractVersion: validatorContractVersion,
            validatorAddress: validatorAddress,
            authenticatorIdHash: authenticatorIdHash,
            authenticatorId: authenticatorId,
            passkeyName: passkeyName,
            domain: domain,
            passkeyServerUrl: URL(string: passkeyServerUrl)
        )
    }
}
