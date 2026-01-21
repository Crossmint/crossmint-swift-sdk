import CrossmintCommonTypes
import Foundation
import Testing
@testable import Wallet

struct BalancesTest {
    @Test(
        "Will handle Balance if the currency is not known"
    )
    func willHandleBalanceIfTheCurrencyIsNotKnown() async {
        let balances = getBalances("""
                [
                  {
                    "symbol": "new_currency",
                    "decimals": 6,
                    "amount": "242",
                    "rawAmount": "242000000",
                    "chains": {
                      "base": {
                        "locator": "base:new_currency",
                        "amount": "121",
                        "rawAmount": "121000000"
                      },
                      "ethereum": {
                        "locator": "ethereum:new_currency",
                        "amount": "121",
                        "rawAmount": "121000000"
                      }
                    }
                  }
                ]
                """
        )

        #expect(balances[.unknown("new_currency")]?.total == 242)
    }

    @Test("Will get the right values for each chain for a given currency")
    func willGetTheRightValuesForEachChainForAGivenCurrency() async {
        let balances = getBalances("""
                [
                  {
                    "symbol": "usdc",
                    "decimals": 6,
                    "amount": "366",
                    "rawAmount": "366000000",
                    "chains": {
                      "base": {
                        "locator": "base:usdc",
                        "amount": "122",
                        "rawAmount": "122000000"
                      },
                      "ethereum": {
                        "locator": "ethereum:usdc",
                        "amount": "121",
                        "rawAmount": "121000000"
                      },
                      "unknown-chain": {
                        "locator": "unknown-chain:usdc",
                        "amount": "123",
                        "rawAmount": "123000000"
                      }
                    }
                  }
                ]
                """
        )

        guard let balance = balances[.usdc] else {
            Issue.record("No balances parsed. Error.")
            return
        }

        #expect(balance.total == 366)
        #expect(balance.chainBalances[.ethereum] == 121)
        #expect(balance.chainBalances[.base] == 122)
        #expect(balance.chainBalances[.unknown(name: "unknown-chain")] == 123)
    }

    @Test("Will get all balances for the same currency together.")
    func willGetAllBalancesForTheSameCurrencyTogether() async {
        let balances = getBalances("""
                [
                  {
                    "symbol": "usdc",
                    "decimals": 6,
                    "amount": "100",
                    "rawAmount": "100000000",
                    "chains": {
                      "ethereum": {
                        "locator": "ethereum:usdc",
                        "amount": "100",
                        "rawAmount": "100000000"
                      }
                    }
                  },
                  {
                    "symbol": "usdc",
                    "decimals": 6,
                    "amount": "200",
                    "rawAmount": "200000000",
                    "chains": {
                      "bsc": {
                        "locator": "bsc:usdc",
                        "amount": "200",
                        "rawAmount": "200000000"
                      }
                    }
                  }
                ]
                """
        )

        guard let usdc = balances[.usdc] else {
            Issue.record("No balances parsed. Error.")
            return
        }

        #expect(usdc.total == 300)
        #expect(usdc[.ethereum] == 100)
        #expect(usdc[.bsc] == 200)
    }

    @Test("Will parse different balances")
    // swiftlint:disable:next function_body_length
    func willGetDifferentTokensFromTheBalanceResponse() async {
        let balances = getBalances("""
                [
                  {
                    "symbol": "eth",
                    "decimals": 18,
                    "amount": "0",
                    "rawAmount": "0",
                    "chains": {
                      "base-sepolia": {
                        "locator": "base-sepolia:eth",
                        "amount": "0",
                        "rawAmount": "0"
                      }
                    }
                  },
                  {
                    "symbol": "usdc",
                    "decimals": 6,
                    "amount": "19.5",
                    "rawAmount": "19500000",
                    "chains": {
                      "base-sepolia": {
                        "locator": "base-sepolia:usdc",
                        "amount": "19.5",
                        "rawAmount": "19500000",
                        "contractAddress": "0x036CbD53842c5426634e7929541eC2318f3dCF7e"
                      }
                    }
                  },
                  {
                    "symbol": "usdxm",
                    "decimals": 6,
                    "amount": "30",
                    "rawAmount": "30000000",
                    "chains": {
                      "base-sepolia": {
                        "locator": "base-sepolia:usdxm",
                        "amount": "30",
                        "rawAmount": "30000000",
                        "contractAddress": "0x14196F08a4Fa0B66B7331bC40dd6bCd8A1dEeA9F"
                      }
                    }
                  }
                ]
                """
        )

        #expect(balances[.eth]?.total == 0)
        #expect(balances[.eth]?[.baseSepolia] == 0)

        #expect(balances[.usdc]?.total == 19.5)
        #expect(balances[.usdc]?[.baseSepolia] == 19.5)

        #expect(balances[.usdxm]?.total == 30)
        #expect(balances[.usdxm]?[.baseSepolia] == 30)
    }

    private func getBalances(_ json: String) -> Balances {
        guard let data = json.data(using: .utf8),
                let balances = try? JSONDecoder().decode(Balances.self, from: data) else {
            Issue.record("Failed to decode balances")
            return Balances()
        }
        return balances
    }
}
