import Foundation
import Testing
@testable import Wallet

struct ExternalSignerTest {
    private let invalidPrivateKey = "invalid key."
    private let validPrivateKey = "133185142a89f6fe2be363c0dcbc1d2e701cbe8c0de5440aeae17c4d3fd28fbd"

    @Test(
        "Will create a new address from a valid private key"
    )
    func willCreateANewAddressFromAValidPrivateKey() async throws {
        let signer = try EVMKeyPairSigner(
            privateKeyData: validPrivateKey.bytes
        )

        try await signer.initialize()

        #expect(await signer.evmAddress.address == "0xa8474496a326b1bf2f7562952130fefe2bee6119")
        // swiftlint:disable:next line_length
        #expect(await signer.publicKey == "0x8c3a79f4c6ca5f2f62677780aefe6ff891fa69f4f97ce7be60f7d90754442411dc941320532121d586de8ec00faa163f9633c797fbe28761060c7ffeb07638f6")
    }

    @Test(
        "Will fail when the private key data provided is empty"
    )
    func willFailWhenEmptyDataIsUsedAsPrivateKey() async throws {
        #expect(throws: SignerError.invalidPrivateKey) {
            try EVMKeyPairSigner(
                privateKeyData: []
            )
        }
    }

    @Test("Will fail when private key is not valid")
    func willFailWhenPrivateKeyIsNotValid() async throws {
        await #expect(throws: SignerError.invalidPrivateKey) {
            let signer = try EVMKeyPairSigner(privateKey: invalidPrivateKey)
            try await signer.initialize()
            _ = try await signer.sign(message: "Message")
        }
    }

    @Test("Will get signature when private key is valid")
    func willGetSignatureWhenPrivateKeyIsValid() async throws {
        let message = "0x52769994aa43c041dad4d211d584bef75e03b318dc8d34a449f815aeb50b99c8"
        let privateKey = "e9b363f475d641078ffd02b477054f8b4c0d3442941bc3d69d15d151ce07be8f"
        // swiftlint:disable:next line_length
        let messageSigned = "0xcb023c8e998f2874bd85fa62dc9228734468cc8bda0f3779ea3c021ee2a3c0677d9d38bf83f7862ff4b1731efdb8d110615b2ed29915c7722283215df88e33111b"

        let signer = try EVMKeyPairSigner(privateKey: privateKey)
        try await signer.initialize()
        let signature = try await signer.sign(message: message)

        #expect(signature == messageSigned)
    }
}
