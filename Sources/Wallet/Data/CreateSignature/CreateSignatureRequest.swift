import CrossmintCommonTypes

public struct CreateSignatureRequest {
    public enum Body {
        case message(SignMessageRequest)
        case typedData(SignTypedDataRequest)
    }

    public let body: Body
    public let chainType: ChainType

    public init(signMessageRequest: SignMessageRequest, chainType: ChainType) {
        self.body = .message(signMessageRequest)
        self.chainType = chainType
    }

    public init(signTypedDataRequest: SignTypedDataRequest, chainType: ChainType) {
        self.body = .typedData(signTypedDataRequest)
        self.chainType = chainType
    }
}
