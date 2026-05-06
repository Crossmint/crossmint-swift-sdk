import CrossmintAuth
import CrossmintCommonTypes
import CrossmintService
import Http
import Logger

public final class DefaultSmartWalletService: SmartWalletService {
    // internal rather than private so extension files across this module can access them
    internal let crossmintService: CrossmintService
    internal let authManager: AuthManager
    internal let jsonCoder: JSONCoder

    public var isProductionEnvironment: Bool {
        crossmintService.isProductionEnvironment
    }

    public init(
        crossmintService: CrossmintService,
        authManager: AuthManager,
        jsonCoder: JSONCoder = DefaultJSONCoder()
    ) {
        self.crossmintService = crossmintService
        self.authManager = authManager
        self.jsonCoder = jsonCoder
    }

    public var authHeaders: [String: String] {
        get async {
            guard let jwt = await authManager.jwt else {
                return [:]
            }

            return [
                "Authorization": "Bearer \(jwt)"
            ]
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

    func signerRegistrationChain(chainType: ChainType, chainName: String) -> String? {
        chainType == .solana || chainType == .stellar ? nil : chainName
    }
}
