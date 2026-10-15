import Testing

@testable import CrossmintCommonTypes

@Suite("FiatCurrency", .tags(.unit))
struct FiatCurrencyTests {

    @Test(arguments: [("mxn", FiatCurrency.mxn), ("xcd", FiatCurrency.xcd)])
    func mapsCodeToPaymentEnabledCurrency(code: String, expected: FiatCurrency) {
        let currency = FiatCurrency(name: code)

        #expect(currency == expected)
        #expect(currency.name == code)
        #expect(currency.isPaymentEnabledFiatCurrency)
    }
}
