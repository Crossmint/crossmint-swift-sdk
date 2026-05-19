import CrossmintCommonTypes
import Foundation
import Testing
@testable import Wallet

struct ChainBalanceTest {
    @Test(
        "Will normalize decimal strings to match the number of decimals",
        arguments: [
            (18, "0.1", "100000000000000000"),
            (6, "1", "1000000"),
            (2, "0.005", "0"),
            (3, "0.005", "5"),
            (6, "123.456789", "123456789"),
            (18, "0", "0"),
            (18, "invalid", nil)
        ]
    )
    // swiftlint:disable:next large_tuple
    func willNormalizeDecimalStrings(values: (Int, String, String?)) async {
        let balance = ChainBalances(total: .zero, decimals: values.0, chainBalances: [:])
        #expect(balance.convertToBaseUnits(values.1) == values.2)
    }
}
