import CrossmintCommonTypes

// @unchecked because Body contains SignTypedDataRequest.TypedData.message: [String: any Encodable],
// which can't satisfy Sendable. Safe in practice — instances are created locally and passed to
// one async call; they are never stored or shared across isolation boundaries.
public struct CreateSignatureRequest: @unchecked Sendable {
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
