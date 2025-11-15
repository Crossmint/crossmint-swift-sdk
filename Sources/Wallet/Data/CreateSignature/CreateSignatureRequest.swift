import CrossmintCommonTypes

protocol SignatureRequestProtocol: Encodable {}

extension SignTypedDataRequest: SignatureRequestProtocol {}
extension SignMessageRequest: SignatureRequestProtocol {}

public struct CreateSignatureRequest {
    let request: any SignatureRequestProtocol
    let chainType: ChainType

    public init(signTypedDataRequest: SignTypedDataRequest, chainType: ChainType) {
        self.request = signTypedDataRequest
        self.chainType = chainType
    }

    public init(signMessageRequest: SignMessageRequest, chainType: ChainType) {
        self.request = signMessageRequest
        self.chainType = chainType
    }
}
