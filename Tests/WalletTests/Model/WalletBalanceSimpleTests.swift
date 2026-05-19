import CrossmintCommonTypes
import Foundation
import Testing
@testable import Wallet

struct WalletBalanceSimpleTest {

    @Test("New Balance structure works correctly")
    func testBalanceStructure() async {
        // Test the new Balance and TokenBalance structures directly
        let nativeToken = TokenBalance(
            symbol: .eth,
            name: "eth",
            amount: "1.5",
            contractAddress: nil,
            decimals: 18,
            rawAmount: "1500000000000000000"
        )

        let usdc = TokenBalance(
            symbol: .usdc,
            name: "usdc",
            amount: "100",
            contractAddress: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
            decimals: 6,
            rawAmount: "100000000"
        )

        let dai = TokenBalance(
            symbol: .symbol("dai"),
            name: "dai",
            amount: "50",
            contractAddress: "0x6B175474E89094C44Da98b954EedeAC495271d0F",
            decimals: 18,
            rawAmount: "50000000000000000000"
        )

        let balance = Balance(
            nativeToken: nativeToken,
            usdc: usdc,
            tokens: [dai]
        )

        // Verify the structure
        #expect(balance.nativeToken.symbol == .eth)
        #expect(balance.nativeToken.amount == "1.5")
        #expect(balance.usdc.symbol == .usdc)
        #expect(balance.usdc.amount == "100")
        #expect(balance.tokens.count == 1)
        #expect(balance.tokens[0].symbol == .symbol("dai"))
    }

    @Test("TokenBalance Symbol enum works correctly")
    func testTokenBalanceSymbol() async {
        #expect(TokenBalance.Symbol.eth.value == "eth")
        #expect(TokenBalance.Symbol.sol.value == "sol")
        #expect(TokenBalance.Symbol.usdc.value == "usdc")
        #expect(TokenBalance.Symbol.symbol("custom").value == "custom")
    }
}
