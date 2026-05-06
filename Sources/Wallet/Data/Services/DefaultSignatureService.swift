import CrossmintCommonTypes
import CrossmintService
import Foundation
import Http

private enum SignatureType: String, Decodable {
    case message
    case typedData = "typed-data"
}

extension DefaultSmartWalletService {
    public func createSignature(
        _ request: CreateSignatureRequest
    ) async throws(SignatureError) -> any SignatureApiModel {
        let endpoint = Endpoint(
            path: "/2025-06-09/wallets/me:\(request.chainType.rawValue)/signatures",
            method: .post,
            headers: await authHeaders,
            body: try jsonCoder.encodeRequest(request.request, errorType: SignatureError.self)
        )

        if request.request is SignMessageRequest {
            return try await crossmintService.executeRequest(
                endpoint,
                errorType: SignatureError.self
            ) as MessageSignatureResponse
        } else {
            return try await crossmintService.executeRequest(
                endpoint,
                errorType: SignatureError.self
            ) as TypedDataSignatureResponse
        }
    }

    public func approveSignature(
        _ request: SignRequest
    ) async throws(SignatureError) {
        try await crossmintService.executeRequest(
            Endpoint(
                path: "/2025-06-09/wallets/me:\(request.chainType.rawValue)/signatures/\(request.transactionId)/approvals",
                method: .post,
                headers: await authHeaders,
                body: try jsonCoder.encodeRequest(request.apiRequest, errorType: SignatureError.self)
            ),
            errorType: SignatureError.self
        )
    }

    public func fetchSignature(
        _ signatureId: String,
        chainType: ChainType
    ) async throws(SignatureError) -> any SignatureApiModel {
        let data = try await crossmintService.executeRequestForRawData(
            Endpoint(
                path: "/2025-06-09/wallets/me:\(chainType.rawValue)/signatures/\(signatureId)",
                method: .get,
                headers: await authHeaders
            ),
            errorType: SignatureError.self
        )

        struct TypeWrapper: Decodable { let type: SignatureType }
        let typeInfo = try decodeSignatureOrThrow(TypeWrapper.self, from: data)

        switch typeInfo.type {
        case .message:
            return try decodeSignatureOrThrow(MessageSignatureResponse.self, from: data)
        case .typedData:
            return try decodeSignatureOrThrow(TypedDataSignatureResponse.self, from: data)
        }
    }

    private func decodeSignatureOrThrow<T: Decodable>(
        _ type: T.Type,
        from data: Data
    ) throws(SignatureError) -> T {
        do {
            return try jsonCoder.decode(type, from: data)
        } catch {
            throw .decodingError
        }
    }
}
