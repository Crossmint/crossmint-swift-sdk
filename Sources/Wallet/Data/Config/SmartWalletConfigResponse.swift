import Foundation

struct SmartWalletConfigResponse: Codable {
    struct Signer: Codable {
        struct Data: Codable {
            private let variant: SignerDataVariant

            var toDomain: AccountWalletConfig.Signer.Data {
                variant.signerData.toDomain
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                let typeString = try container.decode(String.self, forKey: .type)

                guard let type = SignerDataType(rawValue: typeString) else {
                    throw DecodingError.dataCorruptedError(
                        forKey: .type,
                        in: container,
                        debugDescription: "Unknown signer type: \(typeString)"
                    )
                }

                switch type {
                    case .eoa:
                        variant = .eoa(try EOASignerData(from: decoder))
                    case .passkeys:
                        variant = .passkey(try PasskeySignerConfigData(from: decoder))
                }
            }

            func encode(to encoder: Encoder) throws {
                switch variant {
                case .eoa(let eoaData):
                    try eoaData.encode(to: encoder)
                case .passkey(let passkeyData):
                    try passkeyData.encode(to: encoder)
                }
            }

            enum CodingKeys: String, CodingKey {
                case type
            }
        }

        let id: String
        let abstractWalletId: String
        let signerData: Data

        var toDomain: AccountWalletConfig.Signer {
            AccountWalletConfig.Signer(
                id: id,
                abstractWalletId: abstractWalletId,
                signerData: signerData.toDomain
            )
        }

        enum CodingKeys: String, CodingKey {
            case id = "_id"
            case abstractWalletId
            case signerData
        }
    }

    let userId: String
    let smartContractWalletAddress: String?
    let kernelVersion: String
    let entryPointVersion: String
    let signers: [Signer]

    var exists: Bool {
        smartContractWalletAddress != nil
    }

    var toDomain: AccountWalletConfig {
        AccountWalletConfig(
            userId: userId,
            smartContractWalletAddress: smartContractWalletAddress,
            kernelVersion: kernelVersion,
            entryPointVersion: entryPointVersion,
            signers: signers.map { $0.toDomain }
        )
    }
}
