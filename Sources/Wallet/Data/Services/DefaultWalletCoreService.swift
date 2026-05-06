import CrossmintCommonTypes
import CrossmintService
import Http
import Logger

extension DefaultSmartWalletService {
    public func getWallet(
        _ request: GetMeWalletRequest
    ) async throws(WalletError) -> WalletApiModel {
        Logger.smartWallet.info(LogEvents.apiGetWalletStart, attributes: [
            "locator": "me:\(request.chainType.rawValue)"
        ])
        let data = try await crossmintService.executeRequestForRawData(
            Endpoint(
                path: "/2025-06-09/wallets/me:\(request.chainType.rawValue)",
                method: .get,
                headers: await authHeaders
            ),
            errorType: WalletError.self
        )
        let result = try decodeWalletOrThrow(data)
        Logger.smartWallet.info(LogEvents.apiGetWalletSuccess, attributes: ["address": result.address])
        return result
    }

    public func createWallet(
        _ request: CreateWalletParams
    ) async throws(WalletError) -> WalletApiModel {
        Logger.smartWallet.info(LogEvents.apiCreateWalletStart, attributes: [
            "chain": request.chainType.rawValue,
            "type": request.type.rawValue
        ])
        let bodyData = try jsonCoder.encodeRequest(request, errorType: WalletError.self)
        let responseData = try await crossmintService.executeRequestForRawData(
            Endpoint(
                path: "/2025-06-09/wallets/me",
                method: .post,
                headers: await authHeaders,
                body: bodyData
            ),
            errorType: WalletError.self
        )
        let result = try decodeWalletOrThrow(responseData)
        Logger.smartWallet.info(LogEvents.apiCreateWalletSuccess, attributes: ["address": result.address])
        return result
    }

    public func fund(
        _ request: FundWalletRequest
    ) async throws(WalletError) {
        let apiRequest = FundWalletApiRequest(
            token: request.token,
            amount: request.amount,
            chain: request.chain
        )
        try await crossmintService.executeRequest(
            Endpoint(
                path: "/v1-alpha2/wallets/\(request.address)/balances",
                method: .post,
                headers: await authHeaders,
                body: try jsonCoder.encodeRequest(apiRequest, errorType: WalletError.self)
            ),
            errorType: WalletError.self
        )
    }

    public func addSigner(
        _ entry: DelegatedSignerEntry,
        chainType: ChainType,
        chainName: String
    ) async throws(WalletError) -> AddDelegatedSignerResponse {
        let body = RegisterSignerBody(
            signer: entry.signer,
            chain: signerChain(chainType: chainType, chainName: chainName)
        )
        return try await registerSignerBody(body, chainType: chainType)
    }

    public func registerTypedSigner(
        _ signer: any AdminSignerData,
        chainType: ChainType,
        chainName: String
    ) async throws(WalletError) -> AddDelegatedSignerResponse {
        let body = RegisterTypedSignerBody(
            signer: AdminSignerRequestApiModel(signer),
            chain: signerChain(chainType: chainType, chainName: chainName)
        )
        return try await registerSignerBody(body, chainType: chainType)
    }

    public func removeSigner(
        _ signerLocator: String,
        chainType: ChainType,
        chainName: String
    ) async throws(TransactionError) -> any TransactionApiModel {
        let signerLocatorAllowedCharacters = CharacterSet.alphanumerics.union(.init(charactersIn: "-._~:"))
        let encodedLocator = signerLocator.addingPercentEncoding(withAllowedCharacters: signerLocatorAllowedCharacters) ?? signerLocator

        var queryItems: [URLQueryItem] = []
        if let chain = signerChain(chainType: chainType, chainName: chainName) {
            queryItems.append(URLQueryItem(name: "chain", value: chain))
        }

        let endpoint = Endpoint(
            path: "/2025-06-09/wallets/me:\(chainType.rawValue)/signers/\(encodedLocator)",
            method: .delete,
            headers: await authHeaders,
            queryItems: queryItems
        )
        return try await executeTransactionRequest(endpoint: endpoint, mapping: chainType.mappingType)
    }

    private func decodeWalletOrThrow(_ data: Data) throws(WalletError) -> WalletApiModel {
        guard let result = try? jsonCoder.decode(WalletApiModel.self, from: data) else {
            throw WalletError.walletGeneric("Failed to decode wallet response")
        }
        return result
    }

    private func registerSignerBody(
        _ body: some Encodable,
        chainType: ChainType
    ) async throws(WalletError) -> AddDelegatedSignerResponse {
        let bodyData = try jsonCoder.encodeRequest(body, errorType: WalletError.self)
        let responseData = try await crossmintService.executeRequestForRawData(
            .meWalletSigners(chainType: chainType, headers: await authHeaders, body: bodyData),
            errorType: WalletError.self
        )
        do {
            return try jsonCoder.decode(AddDelegatedSignerResponse.self, from: responseData)
        } catch {
            throw WalletError.walletGeneric("Failed to decode signer registration response")
        }
    }
}
