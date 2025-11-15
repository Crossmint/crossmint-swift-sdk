import CrossmintCommonTypes
import Foundation
import Testing
@testable import Wallet

// swiftlint:disable:next type_body_length
struct BalanceTransformerTest {

    // MARK: - Helper Methods

    private func createBalances(from json: String) -> Balances {
        guard let data = json.data(using: .utf8),
              let balances = try? JSONDecoder().decode(Balances.self, from: data) else {
            return Balances()
        }
        return balances
    }

    // MARK: - Basic Functionality Tests

    @Test("Transform balances with all tokens present")
    func testTransformWithAllTokensPresent() async {
        let balancesJson = """
        [
            {
                "symbol": "eth",
                "decimals": 18,
                "amount": "1.5",
                "rawAmount": "1500000000000000000",
                "chains": {
                    "ethereum": {
                        "locator": "ethereum:eth",
                        "amount": "1.5",
                        "rawAmount": "1500000000000000000"
                    }
                }
            },
            {
                "symbol": "usdc",
                "decimals": 6,
                "amount": "100.5",
                "rawAmount": "100500000",
                "chains": {
                    "ethereum": {
                        "locator": "ethereum:usdc",
                        "amount": "100.5",
                        "rawAmount": "100500000"
                    }
                }
            },
            {
                "symbol": "weth",
                "decimals": 18,
                "amount": "50",
                "rawAmount": "50000000000000000000",
                "chains": {
                    "ethereum": {
                        "locator": "ethereum:weth",
                        "amount": "50",
                        "rawAmount": "50000000000000000000"
                    }
                }
            }
        ]
        """

        let balances = createBalances(from: balancesJson)
        let result = BalanceTransformer.transform(
            from: balances,
            nativeToken: .eth,
            requestedTokens: [.weth]
        )

        #expect(result.nativeToken.symbol == .eth)
        #expect(result.nativeToken.amount == "1.5")
        #expect(result.nativeToken.decimals == 18)
        #expect(result.nativeToken.rawAmount == "1500000000000000000")

        #expect(result.usdc.symbol == .usdc)
        #expect(result.usdc.amount == "100.5")
        #expect(result.usdc.decimals == 6)
        #expect(result.usdc.rawAmount == "100500000")

        #expect(result.tokens.count == 1)
        #expect(result.tokens[0].symbol == .symbol("weth"))
        #expect(result.tokens[0].amount == "50")
    }

    @Test("Transform balances with missing USDC")
    func testTransformWithMissingUSDC() async {
        let balancesJson = """
        [
            {
                "symbol": "eth",
                "decimals": 18,
                "amount": "1.0",
                "rawAmount": "1000000000000000000",
                "chains": {
                    "ethereum": {
                        "locator": "ethereum:eth",
                        "amount": "1.0",
                        "rawAmount": "1000000000000000000"
                    }
                }
            }
        ]
        """

        let balances = createBalances(from: balancesJson)
        let result = BalanceTransformer.transform(
            from: balances,
            nativeToken: .eth,
            requestedTokens: []
        )

        #expect(result.nativeToken.symbol == .eth)
        #expect(result.nativeToken.amount == "1")

        // USDC should have default values when not present
        #expect(result.usdc.symbol == .usdc)
        #expect(result.usdc.amount == "0")
        #expect(result.usdc.name == "usdc")
        #expect(result.usdc.decimals == nil)
        #expect(result.usdc.rawAmount == nil)
    }

    @Test("Transform balances with missing native token")
    func testTransformWithMissingNativeToken() async {
        let balancesJson = """
        [
            {
                "symbol": "usdc",
                "decimals": 6,
                "amount": "500",
                "rawAmount": "500000000",
                "chains": {
                    "ethereum": {
                        "locator": "ethereum:usdc",
                        "amount": "500",
                        "rawAmount": "500000000"
                    }
                }
            }
        ]
        """

        let balances = createBalances(from: balancesJson)
        let result = BalanceTransformer.transform(
            from: balances,
            nativeToken: .eth,
            requestedTokens: []
        )

        // Native token should have default values when not present
        #expect(result.nativeToken.symbol == .eth)
        #expect(result.nativeToken.amount == "0")
        #expect(result.nativeToken.name == "eth")
        #expect(result.nativeToken.decimals == nil)
        #expect(result.nativeToken.rawAmount == nil)

        #expect(result.usdc.symbol == .usdc)
        #expect(result.usdc.amount == "500")
    }

    @Test("Transform balances for Solana chain")
    func testTransformForSolanaChain() async {
        let balancesJson = """
        [
            {
                "symbol": "sol",
                "decimals": 9,
                "amount": "5.123456789",
                "rawAmount": "5123456789",
                "chains": {
                    "solana": {
                        "locator": "solana:sol",
                        "amount": "5.123456789",
                        "rawAmount": "5123456789"
                    }
                }
            },
            {
                "symbol": "usdc",
                "decimals": 6,
                "amount": "250.75",
                "rawAmount": "250750000",
                "chains": {
                    "solana": {
                        "locator": "solana:usdc",
                        "amount": "250.75",
                        "rawAmount": "250750000"
                    }
                }
            }
        ]
        """

        let balances = createBalances(from: balancesJson)
        let result = BalanceTransformer.transform(
            from: balances,
            nativeToken: .sol,
            requestedTokens: []
        )

        #expect(result.nativeToken.symbol == .sol)
        #expect(result.nativeToken.amount == "5.123456789")
        #expect(result.nativeToken.decimals == 9)

        #expect(result.usdc.symbol == .usdc)
        #expect(result.usdc.amount == "250.75")
    }

    @Test("Transform balances with multiple tokens")
    func testTransformWithMultipleTokens() async {
        let balancesJson = """
        [
            {
                "symbol": "eth",
                "decimals": 18,
                "amount": "1.0",
                "rawAmount": "1000000000000000000",
                "chains": {
                    "ethereum": {
                        "locator": "ethereum:eth",
                        "amount": "1.0",
                        "rawAmount": "1000000000000000000"
                    }
                }
            },
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
                "symbol": "matic",
                "decimals": 18,
                "amount": "75",
                "rawAmount": "75000000000000000000",
                "chains": {
                    "ethereum": {
                        "locator": "ethereum:matic",
                        "amount": "75",
                        "rawAmount": "75000000000000000000"
                    }
                }
            },
            {
                "symbol": "weth",
                "decimals": 18,
                "amount": "0.5",
                "rawAmount": "500000000000000000",
                "chains": {
                    "ethereum": {
                        "locator": "ethereum:weth",
                        "amount": "0.5",
                        "rawAmount": "500000000000000000"
                    }
                }
            }
        ]
        """

        let balances = createBalances(from: balancesJson)
        let result = BalanceTransformer.transform(
            from: balances,
            nativeToken: .eth,
            requestedTokens: [.matic, .weth]
        )

        #expect(result.nativeToken.symbol == .eth)
        #expect(result.nativeToken.amount == "1")

        #expect(result.usdc.symbol == .usdc)
        #expect(result.usdc.amount == "100")

        // Should have 2 additional tokens (matic and weth)
        #expect(result.tokens.count == 2)

        // Verify token amounts
        for token in result.tokens {
            switch token.symbol {
            case .symbol("matic"):
                #expect(token.amount == "75")
                #expect(token.decimals == 18)
            case .symbol("weth"):
                #expect(token.amount == "0.5")
                #expect(token.decimals == 18)
            default:
                Issue.record("Unexpected token: \(token.symbol)")
            }
        }
    }

    @Test("Transform filters out duplicate native token and USDC from requested tokens")
    func testTransformFiltersOutDuplicates() async {
        let balancesJson = """
        [
            {
                "symbol": "eth",
                "decimals": 18,
                "amount": "1.0",
                "rawAmount": "1000000000000000000",
                "chains": {
                    "ethereum": {
                        "locator": "ethereum:eth",
                        "amount": "1.0",
                        "rawAmount": "1000000000000000000"
                    }
                }
            },
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
                "symbol": "weth",
                "decimals": 18,
                "amount": "50",
                "rawAmount": "50000000000000000000",
                "chains": {
                    "ethereum": {
                        "locator": "ethereum:weth",
                        "amount": "50",
                        "rawAmount": "50000000000000000000"
                    }
                }
            }
        ]
        """

        let balances = createBalances(from: balancesJson)
        // Request includes native token and USDC which should be filtered out
        let result = BalanceTransformer.transform(
            from: balances,
            nativeToken: .eth,
            requestedTokens: [.eth, .usdc, .weth]
        )

        #expect(result.nativeToken.symbol == .eth)
        #expect(result.usdc.symbol == .usdc)

        // Should only have USDT in tokens array (eth and usdc are filtered out)
        #expect(result.tokens.count == 1)
        #expect(result.tokens[0].symbol == .symbol("weth"))
    }

    @Test("Transform handles unknown tokens")
    func testTransformWithUnknownTokens() async {
        let balancesJson = """
        [
            {
                "symbol": "eth",
                "decimals": 18,
                "amount": "1.0",
                "rawAmount": "1000000000000000000",
                "chains": {
                    "ethereum": {
                        "locator": "ethereum:eth",
                        "amount": "1.0",
                        "rawAmount": "1000000000000000000"
                    }
                }
            },
            {
                "symbol": "usdc",
                "decimals": 6,
                "amount": "50",
                "rawAmount": "50000000",
                "chains": {
                    "ethereum": {
                        "locator": "ethereum:usdc",
                        "amount": "50",
                        "rawAmount": "50000000"
                    }
                }
            },
            {
                "symbol": "custom_token",
                "decimals": 12,
                "amount": "999.123456789012",
                "rawAmount": "999123456789012",
                "chains": {
                    "ethereum": {
                        "locator": "ethereum:custom_token",
                        "amount": "999.123456789012",
                        "rawAmount": "999123456789012"
                    }
                }
            }
        ]
        """

        let balances = createBalances(from: balancesJson)
        let result = BalanceTransformer.transform(
            from: balances,
            nativeToken: .eth,
            requestedTokens: [.unknown("custom_token"), .unknown("non_existent")]
        )

        #expect(result.nativeToken.symbol == .eth)
        #expect(result.usdc.symbol == .usdc)

        // Should have 2 tokens (both requested tokens are returned, non_existent with default values)
        #expect(result.tokens.count == 2)

        // Verify the custom_token that exists
        let customToken = result.tokens.first { token in
            if case .symbol("custom_token") = token.symbol { return true }
            return false
        }
        #expect(customToken != nil)
        #expect(customToken?.amount == "999.123456789012")
        #expect(customToken?.decimals == 12)

        // Verify the non_existent token has default values
        let nonExistentToken = result.tokens.first { token in
            if case .symbol("non_existent") = token.symbol { return true }
            return false
        }
        #expect(nonExistentToken != nil)
        #expect(nonExistentToken?.amount == "0")
        #expect(nonExistentToken?.decimals == nil)
    }
}
