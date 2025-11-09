import CrossmintCommonTypes
import Foundation

public struct Price: Codable, Sendable {
    public var amount: String
    public var currency: Currency

    public init(amount: String, currency: Currency) {
        self.amount = amount
        self.currency = currency
    }
}

extension Price {
    public func displayableNumericPrice(cryptoDecimals: Int = 5) -> String {
        if let cryptoCurrency = currency.asCrypto {

            let decimals = cryptoCurrency.getNumericPriceDecimalsPerCurrency(
                defaultValue: cryptoDecimals)

            // TODO DOUBLE we need BigInts or similar to avoid precision loss
            return String(format: "%.\(decimals)f", (Double(amount) ?? 0)) + " "
                + cryptoCurrency.name.uppercased()

        } else if let fiatCurrency = currency.asFiat {
            if !fiatCurrency.isPaymentEnabledFiatCurrency {
                return "Currency \(fiatCurrency.name) is not supported"
            }

            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = fiatCurrency.name.uppercased()
            formatter.locale = Foundation.Locale(identifier: "en_US")

            // TODO DOUBLE we need BigInts or similar to avoid precision loss
            if let amount = Double(amount),
                let formattedAmount = formatter.string(from: NSNumber(value: amount)) {
                return formattedAmount
            }

            // Fallback if formatting failed
            return String(format: "%.2f", (Double(amount) ?? 0)) + " "
                + fiatCurrency.name.uppercased()

        } else {
            return "Currency \(currency.name) is not supported"
        }
    }
}
