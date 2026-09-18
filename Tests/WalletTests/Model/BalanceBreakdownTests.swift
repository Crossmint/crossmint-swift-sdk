import CrossmintCommonTypes
import Foundation
import Testing
import TestsUtils
@testable import Wallet

struct BalanceBreakdownTest {

    @Test("Keeps available and locked alongside the total amount")
    func keepsAvailableAndLockedAlongsideTheTotal() throws {
        let result = try transformBreakdown(chain: .stellar)

        #expect(result.usdc.amount == "1255.5")
        #expect(result.usdc.available == TokenAmount(amount: "1210.5", rawAmount: "12105000000"))
        #expect(result.usdc.locked == TokenAmount(amount: "40", rawAmount: "400000000"))
        #expect(result.nativeToken.available == TokenAmount(amount: "9", rawAmount: "90000000"))
    }

    @Test("Keeps each readable account with its own amounts and provider")
    func keepsEachReadableAccountWithItsOwnAmountsAndProvider() throws {
        let accounts = try #require(try transformBreakdown(chain: .stellar).usdc.accounts)

        #expect(accounts.map(\.type) == [
            .wallet,
            .card(provider: "rain"),
            .unknown("card"),
            .unknown(""),
            .unknown("escrow")
        ])

        let card = try #require(accounts.first { $0.type == .card(provider: "rain") })
        #expect(card.amount == "1000")
        #expect(card.available == TokenAmount(amount: "960", rawAmount: "9600000000"))
        #expect(card.locked == TokenAmount(amount: "40", rawAmount: "400000000"))
        #expect(accounts.first?.amount == "250.5")
    }

    @Test("Keeps the breakdown of a requested token that reports no accounts")
    func keepsTheBreakdownOfARequestedTokenThatReportsNoAccounts() throws {
        let result = try transformBreakdown(chain: .stellar, requestedTokens: [.usdxm])

        let usdxm = try #require(result.tokens.first { $0.symbol == .symbol("usdxm") })
        #expect(usdxm.available == TokenAmount(amount: "7", rawAmount: "7000000"))
        #expect(usdxm.accounts == nil)
    }

    @Test("Returns the breakdown of the requested chain only")
    func returnsTheBreakdownOfTheRequestedChainOnly() throws {
        let stellar = try transformBreakdown(chain: .stellar)
        let solana = try transformBreakdown(chain: .solana)

        #expect(stellar.usdc.available == TokenAmount(amount: "1210.5", rawAmount: "12105000000"))
        #expect(solana.usdc.available == TokenAmount(amount: "5", rawAmount: "50000000"))
        #expect(solana.usdc.accounts == nil)
    }

    @Test("Uses the first entry when a token is reported twice")
    func usesTheFirstEntryWhenATokenIsReportedTwice() throws {
        let balances = try balancesFixture("BalancesRepeatedToken")
        let result = BalanceTransformer.transform(
            from: balances,
            nativeToken: .xlm,
            requestedTokens: [],
            chain: .stellar
        )

        #expect(result.usdc.amount == "10")
        #expect(result.usdc.rawAmount == "10000000")
        #expect(result.usdc.available == TokenAmount(amount: "1", rawAmount: "1000000"))
        #expect(result.usdc.locked == nil)
        #expect(result.usdc.accounts?.map(\.type) == [.wallet])
    }

    @Test(
        "Reports no raw amount when the token reports none that can be read",
        arguments: [(CryptoCurrency.eurc, "40.50"), (CryptoCurrency.bonk, "50")]
    )
    func reportsNoRawAmountWhenTheTokenReportsNoneThatCanBeRead(values: (CryptoCurrency, String)) throws {
        let balances = try balancesFixture("BalancesMalformedBreakdown")
        let result = BalanceTransformer.transform(
            from: balances,
            nativeToken: .xlm,
            requestedTokens: [values.0],
            chain: .stellar
        )

        let token = try #require(result.tokens.first)
        #expect(token.amount == values.1)
        #expect(token.rawAmount == nil)
    }

    @Test("Leaves the breakdown out when no chain is requested")
    @available(*, deprecated, message: "Covers the deprecated overload that takes no chain")
    func leavesTheBreakdownOutWhenNoChainIsRequested() throws {
        let balances = try balancesFixture("BalancesBreakdown")
        let result = BalanceTransformer.transform(
            from: balances,
            nativeToken: .xlm,
            requestedTokens: []
        )

        #expect(result.usdc.amount == "1255.5")
        #expect(result.usdc.available == nil)
        #expect(result.usdc.locked == nil)
        #expect(result.usdc.accounts == nil)
    }

    private func transformBreakdown(
        chain: Chain,
        requestedTokens: [CryptoCurrency] = []
    ) throws -> Balance {
        let balances = try balancesFixture("BalancesBreakdown")
        return BalanceTransformer.transform(
            from: balances,
            nativeToken: .xlm,
            requestedTokens: requestedTokens,
            chain: chain
        )
    }

    private func balancesFixture(_ fileName: String) throws -> Balances {
        try GetFromFile.getModelFrom(fileName: fileName, bundle: Bundle.module)
    }
}
