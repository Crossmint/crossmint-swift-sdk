import CrossmintCommonTypes
import CrossmintService
import Http
import Logger

struct DefaultWalletService: WalletService {
    let crossmintService: CrossmintService
    let jsonCoder: JSONCoder

    var isProductionEnvironment: Bool { crossmintService.isProductionEnvironment }

    func getWallet(_ request: GetMeWalletRequest) async throws(WalletError) -> WalletApiModel {
        Logger.smartWallet.info(LogEvents.apiGetWalletStart, attributes: [
            "locator": "me:\(request.chainType.rawValue)"
        ])
        let data = try await crossmintService.executeRequestForRawData(
            Endpoint.meWallet(chainType: request.chainType),
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
            Endpoint.createMeWallet(body: bodyData),
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
            Endpoint.fundWallet(address: "\(request.address)", body: body),
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
            queryItems: queryItems
        )
        let data = try await crossmintService.executeRequestForRawData(endpoint, errorType: TransactionError.self)
        return try decodeTransaction(from: data, mapping: chainType.mappingType)
    }

    func getSigner(
        _ signerLocator: String,
        chainType: ChainType
    ) async throws(WalletError) -> AddDelegatedSignerResponse {
        Logger.smartWallet.info(LogEvents.apiGetSignerStart, attributes: ["locator": signerLocator])
        let endpoint = Endpoint.getSigner(
            chainType: chainType,
            encodedLocator: encodedSignerLocator(signerLocator)
        )
        let data = try await crossmintService.executeRequestForRawData(endpoint, errorType: WalletError.self)
        guard let result = try? jsonCoder.decode(AddDelegatedSignerResponse.self, from: data) else {
            throw WalletError.walletGeneric("Failed to decode signer response")
        }
        Logger.smartWallet.info(LogEvents.apiGetSignerSuccess, attributes: ["locator": signerLocator])
        return result
    }

    private func decodeTransaction<T: WalletTypeTransactionMapping>(
        from data: Data,
        mapping: T.Type
    ) throws(TransactionError) -> any TransactionApiModel {
        do {
            return try jsonCoder.decode(T.APIModel.self, from: data)
        } catch {
            throw TransactionError.transactionGeneric("Failed to decode transaction response")
        }
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
            .meWalletSigners(chainType: chainType, body: bodyData),
            errorType: WalletError.self
        ) { networkError in
            mapToDeviceSignerNotSupportedErrorIfApplicable(
                code: networkError.serviceErrorCode,
                message: networkError.serviceErrorMessage
            )
        }
        guard let result = try? jsonCoder.decode(AddDelegatedSignerResponse.self, from: responseData) else {
            throw WalletError.walletGeneric("Failed to decode signer registration response")
        }
        return result
    }

    private func mapToDeviceSignerNotSupportedErrorIfApplicable(code: String?, message: String?) -> WalletError? {
        guard code == "DEVICE_SIGNER_NOT_SUPPORTED" else { return nil }
        return .deviceSignerNotSupported(
            message ?? "Device signers are not supported for this wallet's provider."
        )
    }

    private func signerRegistrationChain(chainType: ChainType, chainName: String) -> String? {
        chainType == .solana || chainType == .stellar ? nil : chainName
    }
}
