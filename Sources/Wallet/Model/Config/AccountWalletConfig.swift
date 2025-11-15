import Foundation

public struct AccountWalletConfig {
    let userId: String
    let smartContractWalletAddress: String?
    let kernelVersion: String
    let entryPointVersion: String
    let signers: [Signer]

    var exists: Bool {
        smartContractWalletAddress != nil
    }

    public struct Signer {
        let id: String
        let abstractWalletId: String
        let signerData: Data

        public struct Data {

            public enum SignerType: String {
                case eoa
                case passkeys
            }

            let type: SignerType

            // EOA signer fields
            let eoaAddress: String?

            // Passkey signer fields
            let pubKeyX: String?
            let pubKeyY: String?
            let entryPoint: String?
            let validatorContractVersion: String?
            let validatorAddress: String?
            let authenticatorIdHash: String?
            let authenticatorId: String?
            let passkeyName: String?
            let domain: String?
            let passkeyServerUrl: URL?

            var isEOA: Bool {
                return type == .eoa
            }

            var isPasskey: Bool {
                return type == .passkeys
            }
        }
    }
}
