import CrossmintAuth
import CrossmintCommonTypes
import CrossmintService
import Http
import Logger

struct DefaultWalletService: WalletService {
    let crossmintService: CrossmintService
    let jsonCoder: JSONCoder
    let authManager: AuthManager

    var isProductionEnvironment: Bool { crossmintService.isProductionEnvironment }

    var authHeaders: [String: String] {
        get async {
            guard let jwt = await authManager.jwt else { return [:] }
            return ["Authorization": "Bearer \(jwt)"]
        }
    }

    func executeTransactionRequest<T: WalletTypeTransactionMapping>(
        endpoint: Endpoint,
        mapping: T.Type
    ) async throws(TransactionError) -> any TransactionApiModel {
        let data = try await crossmintService.executeRequestForRawData(
            endpoint,
            errorType: TransactionError.self
        )
        do {
            return try jsonCoder.decode(T.APIModel.self, from: data)
        } catch {
            throw TransactionError.transactionGeneric("Failed to decode transaction response")
        }
    }

    func getWallet(_ request: GetMeWalletRequest) async throws(WalletError) -> WalletApiModel {
        Logger.smartWallet.info(LogEvents.apiGetWalletStart, attributes: [
            "locator": "me:\(request.chainType.rawValue)"
        ])
        let data = try await crossmintService.executeRequestForRawData(
            Endpoint.meWallet(chainType: request.chainType, headers: await authHeaders),
            errorType: WalletError.self
        )
        let result = try decodeWalletOrThrow(data)
        Logger.smartWallet.info(LogEvents.apiGetWalletSuccess, attributes: ["address": result.address])
        return result
    }

    func createWallet(_ request: CreateWalletParams) async throws(WalletError) -> WalletApiModel {
        Logger.smartWallet.info(LogEvents.apiCreateWalletStart, attributes: [
            "chain": request.chainType.rawValue,
            "type": request.type.rawValue
        ])
        let bodyData = try jsonCoder.encodeRequest(request, errorType: WalletError.self)
        let responseData = try await crossmintService.executeRequestForRawData(
            Endpoint.createMeWallet(headers: await authHeaders, body: bodyData),
            errorType: WalletError.self
        )
        let result = try decodeWalletOrThrow(responseData)
        Logger.smartWallet.info(LogEvents.apiCreateWalletSuccess, attributes: ["address": result.address])
        return result
    }

    func fund(_ request: FundWalletRequest) async throws(WalletError) {
        let apiRequest = FundWalletApiRequest(token: request.token, amount: request.amount, chain: request.chain)
        let body = try jsonCoder.encodeRequest(apiRequest, errorType: WalletError.self)
        try await crossmintService.executeRequest(
            Endpoint.fundWallet(address: "\(request.address)", headers: await authHeaders, body: body),
            errorType: WalletError.self
        )
    }

    func addSigner(
        _ entry: DelegatedSignerEntry,
        chainType: ChainType,
        chainName: String
    ) async throws(WalletError) -> AddDelegatedSignerResponse {
        let body = RegisterSignerBody(
            signer: entry.signer,
            chain: signerRegistrationChain(chainType: chainType, chainName: chainName)
        )
        return try await registerSignerBody(body, chainType: chainType)
    }

    func registerTypedSigner(
        _ signer: any AdminSignerData,
        chainType: ChainType,
        chainName: String
    ) async throws(WalletError) -> AddDelegatedSignerResponse {
        let body = RegisterTypedSignerBody(
            signer: AdminSignerRequestApiModel(signer),
            chain: signerRegistrationChain(chainType: chainType, chainName: chainName)
        )
        return try await registerSignerBody(body, chainType: chainType)
    }

    func removeSigner(
        _ signerLocator: String,
        chainType: ChainType,
        chainName: String
    ) async throws(TransactionError) -> any TransactionApiModel {
        let encodedLocator = encodedSignerLocator(signerLocator)
        var queryItems: [URLQueryItem] = []
        if let chain = signerRegistrationChain(chainType: chainType, chainName: chainName) {
            queryItems.append(URLQueryItem(name: "chain", value: chain))
        }
        let endpoint = Endpoint.removeSigner(
            chainType: chainType,
            encodedLocator: encodedLocator,
            headers: await authHeaders,
            queryItems: queryItems
        )
        return try await executeTransactionRequest(endpoint: endpoint, mapping: chainType.mappingType)
    }

    private func encodedSignerLocator(_ locator: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(.init(charactersIn: "-._~:"))
        return locator.addingPercentEncoding(withAllowedCharacters: allowed) ?? locator
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
        guard let result = try? jsonCoder.decode(AddDelegatedSignerResponse.self, from: responseData) else {
            throw WalletError.walletGeneric("Failed to decode signer registration response")
        }
        return result
    }

    private func signerRegistrationChain(chainType: ChainType, chainName: String) -> String? {
        chainType == .solana || chainType == .stellar ? nil : chainName
    }
}
