import Testing
@testable import Payments

struct TokenLocatorTest {
    @Test(
        "Will return the correct token locator for the given type",
        arguments: [
            (
                "solana:6p6xgHyF7AeE6TZkSmFsko444wqoP15icUSqi2jfGiPN",
                TokenLocator.solana(
                    // swiftlint:disable:next force_try
                    try! SolanaTokenLocator(string: "solana:6p6xgHyF7AeE6TZkSmFsko444wqoP15icUSqi2jfGiPN")
                )
            ),
            (
                "apex:0x0123456789012345678901234567890123456789:5",
                TokenLocator.evm(
                    EvmTokenLocator(
                        chain: .apex,
                        // swiftlint:disable:next force_try
                        contractAddress: try! .init(address: "0x0123456789012345678901234567890123456789"),
                        tokenId: "5"
                    )
                )
            )
        ]
    )
    func willReturnTheCorrectTokenLocatorForTheGivenType(expectAndActual: (String, TokenLocator)) async {
        do {
            let tokenLocator = try TokenLocator(string: expectAndActual.0)
            #expect(tokenLocator.description == expectAndActual.1.description)
        } catch {
            Issue.record("Invalid token locator for: \(expectAndActual.0) ~ \(error.localizedDescription)")
        }
    }
}
