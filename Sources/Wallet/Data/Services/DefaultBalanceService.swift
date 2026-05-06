import CrossmintCommonTypes
import CrossmintService
import Foundation
import Http

extension DefaultSmartWalletService {
    public func getBalance(
        _ params: GetBalanceQueryParams
    ) async throws(WalletError) -> Balances {
        let tokens: [CryptoCurrency] = params.tokens.isEmpty ? CryptoCurrency.allCases : params.tokens
        let tokenValue = tokens.map(\.name).joined(separator: ",")
        var queryItems: [URLQueryItem] = [.init(name: "tokens", value: tokenValue)]

        if !params.chains.isEmpty {
            let chainValue = params.chains.map(\.name).joined(separator: ",")
            queryItems.append(.init(name: "chains", value: chainValue))
        }

        return try await crossmintService.executeRequest(
            Endpoint(
                path: "/2025-06-09/wallets/\(params.walletLocator.value)/balances",
                method: .get,
                headers: await authHeaders,
                queryItems: queryItems
            ),
            errorType: WalletError.self
        )
    }
}
