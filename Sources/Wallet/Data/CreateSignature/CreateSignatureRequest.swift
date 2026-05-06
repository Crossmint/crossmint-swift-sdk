import CrossmintCommonTypes

protocol SignatureRequestProtocol: Encodable {}

extension SignTypedDataRequest: SignatureRequestProtocol {}
extension SignMessageRequest: SignatureRequestProtocol {}

public struct CreateSignatureRequest {
    public enum ResponseType {
        case message
        case typedData
    }

    let request: any SignatureRequestProtocol
    let chainType: ChainType
    let responseType: ResponseType

    public init(signMessageRequest: SignMessageRequest, chainType: ChainType) {
        self.request = signMessageRequest
        self.chainType = chainType
        self.responseType = .message
    }

    public init(signTypedDataRequest: SignTypedDataRequest, chainType: ChainType) {
        self.request = signTypedDataRequest
        self.chainType = chainType
        self.responseType = .typedData
    }
}
