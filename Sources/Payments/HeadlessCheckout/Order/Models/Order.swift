import CrossmintCommonTypes
import Foundation
import Utils

public struct Order: Codable, Sendable, Identifiable {
    public var orderId: UUID
    public var phase: OrderPhase
    public var locale: Locale
    public var lineItems: [LineItem]
    public var quote: OrderQuote
    public var payment: OrderPayment

    public var id: UUID { orderId }

    // TODO verify that exact-in orders have only one item
}

extension Order {
    public var lineItemDeliveryRecipient: LineItemDeliveryRecipient? {
        lineItems.first?.delivery.recipient
    }

    public var lineItemDeliveryChain: Chain? {
        lineItems.first?.chain
    }

    public var isMultiTokenOrder: Bool {

        let isMultiLineItems = lineItems.count > 1
        let isMultiQuantity = lineItems.first {
            switch $0 {
            case .exactOut(let item):
                return item.quantity > 1
            default:
                return false
            }
        }

        return isMultiLineItems || isMultiQuantity != nil

    }

    public var orderIdString: String {
        orderId.uuidString.lowercased()
    }

    public var areAllLineItemsFailed: Bool {
        lineItems.allSatisfy { item in
            item.delivery.failed != nil
        }
    }

    public var orderModeExactIn: Bool {
        lineItems.first?.exactIn != nil
    }

    public var tokenQuantityAndName: String? {
        guard orderModeExactIn else {
            return nil
        }

        guard let lineItemExactIn = lineItems.first?.exactIn else {
            return nil
        }

        // Extract quantity from delivered tokens
        guard let deliveredTokens = lineItemExactIn.delivery.delivered?.tokens.first,
            let solanaToken = deliveredTokens.solana,
            let exactInToken = solanaToken.exactIn,
            !isEmpty(exactInToken.quantity)
        else {
            return nil
        }

        // Extract mint hash from execution params
        guard let executionParams = lineItemExactIn.executionParams,
            let mintHash = executionParams["mintHash"] as? String,
            !isEmpty(mintHash)
        else {
            return nil
        }

        let tokenName = lineItemExactIn.metadata.name
        return "\(exactInToken.quantity) \(tokenName.uppercased())"
    }

    public var itemCount: Int {
        lineItems.reduce(0) { count, item in
            switch item {
            case .exactOut(let exactOutItem):
                return count + exactOutItem.quantity
            case .exactIn:
                return count + 1
            }
        }
    }

    // TODO: need to return a bignumber since we will have over/underflows
    public var gasFees: Decimal {
        var sum = Decimal.zero

        for item in lineItems {
            if let gasAmount = item.quote.charges?.gas?.amount,
                let gasDecimal = Decimal(string: gasAmount) {
                sum += gasDecimal
            }
        }
        return sum
    }
}
