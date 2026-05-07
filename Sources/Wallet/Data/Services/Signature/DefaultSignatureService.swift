import CrossmintAuth
import CrossmintCommonTypes
import CrossmintService
import Foundation
import Http

private enum SignatureType: String, Decodable {
    case message
    case typedData = "typed-data"
}

struct DefaultSignatureService: SignatureService, AuthManagerProviding {
    let crossmintService: CrossmintService
    let jsonCoder: JSONCoder
    let authManager: AuthManager

    func createSignature(
        _ request: CreateSignatureRequest
    ) async throws(SignatureError) -> any SignatureApiModel {
        switch request.body {
        case .message(let r):
            let response: MessageSignatureResponse = try await executeSignatureRequest(r, chainType: request.chainType)
            return response
        case .typedData(let r):
            let response: TypedDataSignatureResponse = try await executeSignatureRequest(r, chainType: request.chainType)
            return response
        }
    }

    private func executeSignatureRequest<Response: SignatureApiModel>(
        _ signRequest: some Encodable,
        chainType: ChainType
    ) async throws(SignatureError) -> Response {
        let body = try jsonCoder.encodeRequest(signRequest, errorType: SignatureError.self)
        let endpoint = Endpoint.createSignature(chainType: chainType, headers: await authHeaders, body: body)
        return try await crossmintService.executeRequest(endpoint, errorType: SignatureError.self)
    }

    func approveSignature(_ request: SignRequest) async throws(SignatureError) {
        let body = try jsonCoder.encodeRequest(request.apiRequest, errorType: SignatureError.self)
        try await crossmintService.executeRequest(
            Endpoint.approveSignature(
                chainType: request.chainType,
                signatureId: request.transactionId,
                headers: await authHeaders,
                body: body
            ),
            errorType: SignatureError.self
        )
    }

    func fetchSignature(
        _ signatureId: String,
        chainType: ChainType
    ) async throws(SignatureError) -> any SignatureApiModel {
        let data = try await crossmintService.executeRequestForRawData(
            Endpoint.fetchSignature(
                chainType: chainType,
                signatureId: signatureId,
                headers: await authHeaders
            ),
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
        guard let result = try? jsonCoder.decode(type, from: data) else {
            throw SignatureError.decodingError
        }
        return result
    }
}
