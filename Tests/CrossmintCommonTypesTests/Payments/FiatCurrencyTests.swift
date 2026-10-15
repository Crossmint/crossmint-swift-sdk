import Foundation
import Testing

@testable import CrossmintCommonTypes

@Suite("FiatCurrency", .tags(.unit))
struct FiatCurrencyTests {

    @Test(arguments: [("mxn", FiatCurrency.mxn), ("xcd", FiatCurrency.xcd)])
    func mapsCurrencyCodeToKnownCase(code: String, expected: FiatCurrency) {
        let currency = FiatCurrency(name: code)

        #expect(currency == expected)
        #expect(currency.name == code)
    }

    @Test(arguments: [FiatCurrency.mxn, FiatCurrency.xcd])
    func enablesPaymentsInCurrency(currency: FiatCurrency) {
        #expect(currency.isPaymentEnabledFiatCurrency)
    }

    @Test(arguments: [FiatCurrency.mxn, FiatCurrency.xcd])
    func encodesCurrencyAsItsCode(currency: FiatCurrency) throws {
        let data = try JSONEncoder().encode(currency)

        #expect(String(bytes: data, encoding: .utf8) == "\"\(currency.name)\"")
    }

    @Test func keepsUnlistedCodeAsUnknown() {
        let currency = FiatCurrency(name: "chf")

        #expect(currency == .unknown("chf"))
        #expect(!currency.isPaymentEnabledFiatCurrency)
    }
}
