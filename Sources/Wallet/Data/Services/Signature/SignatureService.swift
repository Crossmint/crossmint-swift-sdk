import CrossmintCommonTypes
import CrossmintService

public protocol SignatureService: AuthenticatedService, Sendable {
    func createSignature(
        _ request: CreateSignatureRequest
    ) async throws(SignatureError) -> any SignatureApiModel

    func approveSignature(
        _ request: SignRequest
    ) async throws(SignatureError)

    func fetchSignature(
        _ signatureId: String,
        chainType: ChainType
    ) async throws(SignatureError) -> any SignatureApiModel
}
