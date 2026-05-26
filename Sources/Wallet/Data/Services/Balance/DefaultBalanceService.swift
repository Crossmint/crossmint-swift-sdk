import CrossmintCommonTypes
import CrossmintService
import Foundation
import Http

struct DefaultBalanceService: BalanceService {
    let crossmintService: CrossmintService

    func getBalance(_ params: GetBalanceQueryParams) async throws(WalletError) -> Balances {
        let tokens: [CryptoCurrency] = params.tokens.isEmpty ? CryptoCurrency.allCases : params.tokens
        let tokenValue = tokens.map(\.name).joined(separator: ",")
        var queryItems: [URLQueryItem] = [.init(name: "tokens", value: tokenValue)]

        if !params.chains.isEmpty {
            let chainValue = params.chains.map(\.name).joined(separator: ",")
            queryItems.append(.init(name: "chains", value: chainValue))
        }

        return try await crossmintService.executeRequest(
            Endpoint.walletBalances(
                walletLocator: params.walletLocator.value,
                queryItems: queryItems
            ),
            errorType: WalletError.self
        )
    }
}
