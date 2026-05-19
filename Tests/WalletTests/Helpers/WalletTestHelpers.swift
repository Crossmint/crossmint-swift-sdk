import Foundation
import Testing
@testable import Wallet

func decodeBalances(from json: String) -> Balances {
    guard let data = json.data(using: .utf8),
          let balances = try? JSONDecoder().decode(Balances.self, from: data) else {
        Issue.record("Failed to decode balances from JSON")
        return Balances()
    }
    return balances
}
