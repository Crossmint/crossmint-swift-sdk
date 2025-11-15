import Testing
@testable import Wallet
import CrossmintCommonTypes
import Foundation

struct SignMessageTests {

    @Test
    func signMessageRequestEncoding() throws {
        let request = SignMessageRequest(
            params: SignMessageRequest.Params(
                message: "Hello, world!",
                chain: Chain.polygon,
                signer: nil,
                isSmartWalletSignature: false
            )
        )

        let json = try encodeToJSON(request)
        let params = getParams(from: json)

        #expect(json["type"] as? String == "message")
        #expect(params["message"] as? String == "Hello, world!")
        #expect(params["chain"] as? String == "polygon")
        #expect(params["isSmartWalletSignature"] as? Bool == false)
    }

    @Test
    func signMessageRequestWithSigner() throws {
        let signer = EmailSignerData(email: "user@example.com")
        let request = SignMessageRequest(
            params: SignMessageRequest.Params(
                message: "Sign this message",
                chain: Chain.polygon,
                signer: signer,
                isSmartWalletSignature: true
            )
        )

        let json = try encodeToJSON(request)
        let params = getParams(from: json)

        #expect(params["signer"] as? String == "email:user@example.com")
        #expect(params["isSmartWalletSignature"] as? Bool == true)
    }

    @Test
    func createSignatureRequestWithMessage() {
        let messageRequest = SignMessageRequest(
            params: SignMessageRequest.Params(
                message: "Test message",
                chain: Chain.ethereum,
                signer: nil,
                isSmartWalletSignature: false
            )
        )

        let createRequest = CreateSignatureRequest(
            signMessageRequest: messageRequest,
            chainType: ChainType.evm
        )

        #expect(createRequest.chainType == ChainType.evm)
        #expect(createRequest.request is SignMessageRequest)
    }

    @Test
    func createSignatureRequestWithTypedData() {
        let typedDataRequest = SignTypedDataRequest(
            params: SignTypedDataRequest.Params(
                typedData: SignTypedDataRequest.TypedData(
                    domain: SignTypedDataRequest.TypedData.Domain(
                        name: "Test",
                        version: "1",
                        chainId: 1,
                        verifyingContract: "0x123"
                    ),
                    types: [:],
                    primaryType: "Test",
                    message: [:]
                ),
                chain: Chain.ethereum,
                signer: nil,
                isSmartWalletSignature: false
            )
        )

        let createRequest = CreateSignatureRequest(
            signTypedDataRequest: typedDataRequest,
            chainType: ChainType.evm
        )

        #expect(createRequest.chainType == ChainType.evm)
        #expect(createRequest.request is SignTypedDataRequest)
    }

    private func encodeToJSON(_ encodable: any Encodable) throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(encodable)
        // swiftlint:disable:next force_cast
        return try JSONSerialization.jsonObject(with: data) as! [String: Any]
    }

    private func getParams(from json: [String: Any]) -> [String: Any] {
        // swiftlint:disable:next force_cast
        return json["params"] as! [String: Any]
    }
}
