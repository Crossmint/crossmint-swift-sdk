import Foundation
import Testing
import TestsUtils

@testable import Payments

@Suite("Order Tests", .tags(.unit))
struct OrderTests {
    @Test("Parses a LineItemDeliveryToken")
    func parsesLineItemDeliveryToken() async throws {
        let lineItemDeliveryToken: LineItemDeliveryToken = try GetFromFile.getModelFrom(
            fileName: "GetLineItemDeliveryToken",
            bundle: Bundle.module
        )

        // Check if the token is a Solana token
        switch lineItemDeliveryToken {
        case .solana(let solanaItemDeliveryToken):
            guard case .exactIn = solanaItemDeliveryToken else {
                Issue.record("Expected .exactIn but got \(solanaItemDeliveryToken)")
                return
            }
            // Test passes if we have a .solana case
            #expect(Bool(true))
        case .evm:
            Issue.record("Expected a Solana token but got an EVM token")
        }
    }

    @Test("Parses a SolanaLineItemDeliveryToken of exact out type")
    func parsesSolanaLineItemDeliveryTokenExactOut() async throws {
        let lineItemDeliveryToken: LineItemDeliveryToken = try GetFromFile.getModelFrom(
            fileName: "SolanaLineItemDeliveryTokenOut",
            bundle: Bundle.module
        )

        guard case .solana(let solanaItemDeliveryToken) = lineItemDeliveryToken else {
            Issue.record("Expected a Solana token but got an EVM token")
            return
        }

        guard case .exactOut(let deliveryToken) = solanaItemDeliveryToken else {
            Issue.record("Expected .exactOut but got \(solanaItemDeliveryToken)")
            return
        }

        // swiftlint:disable:next force_try
        let expectedToken = try! SolanaTokenLocator(
            string: "solana:6p6xgHyF7AeE6TZkSmFsko444wqoP15icUSqi2jfGiPN")
        #expect(deliveryToken.locator.description == TokenLocator.solana(expectedToken).description)
    }
}
