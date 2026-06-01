import Combine

// Retroactive CrossmintTEEProtocol conformance for the WebView-backed TEE.
// isOTPRequiredPublisher bridges the @Published property to the protocol's
// AnyPublisher requirement without touching the existing class body.
extension CrossmintTEE: CrossmintTEEProtocol {
    public var isOTPRequiredPublisher: AnyPublisher<Bool, Never> {
        $isOTPRequired.eraseToAnyPublisher()
    }
}
