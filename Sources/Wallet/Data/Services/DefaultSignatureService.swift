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
        let body = try jsonCoder.encodeRequest(request.request, errorType: SignatureError.self)
        let endpoint = Endpoint.createSignature(chainType: request.chainType, headers: await authHeaders, body: body)
        switch request.responseType {
        case .message:
            return try await crossmintService.executeRequest(endpoint, errorType: SignatureError.self) as MessageSignatureResponse
        case .typedData:
            return try await crossmintService.executeRequest(endpoint, errorType: SignatureError.self) as TypedDataSignatureResponse
        }
    }

    public func approveSignature(
        _ request: SignRequest
    ) async throws(SignatureError) {
        let body = try jsonCoder.encodeRequest(request.apiRequest, errorType: SignatureError.self)
        try await crossmintService.executeRequest(
            Endpoint.approveSignature(chainType: request.chainType, signatureId: request.transactionId, headers: await authHeaders, body: body),
            errorType: SignatureError.self
        )
    }

    public func fetchSignature(
        _ signatureId: String,
        chainType: ChainType
    ) async throws(SignatureError) -> any SignatureApiModel {
        let data = try await crossmintService.executeRequestForRawData(
            Endpoint.fetchSignature(chainType: chainType, signatureId: signatureId, headers: await authHeaders),
            errorType: SignatureError.self
        )
        return try decodeSignatureByType(from: data)
    }

    private func decodeSignatureByType(from data: Data) throws(SignatureError) -> any SignatureApiModel {
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
        try jsonCoder.decodeOrThrow(type, from: data, onFailure: SignatureError.decodingError)
    }
}
