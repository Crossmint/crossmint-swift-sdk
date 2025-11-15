import Testing

@testable import Wallet

struct WalletLocatorTest {
    @Test(
        "Will return the correct wallet locator for the given type",
        arguments: [
            (
                "0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d",
                // swiftlint:disable:next force_try
                WalletLocator.address(.evm(try! .init(address: "0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d")))
            ),
            (
                "email:email@paella.dev:evm",
                WalletLocator.owner(.email("email@paella.dev"), .evm)
            ),
            (
                "userId:userID:evm",
                WalletLocator.owner(.userId("userID"), .evm)
            ),
            (
                "phoneNumber:555-1239:evm",
                WalletLocator.owner(.phoneNumber("555-1239"), .evm)
            ),
            (
                "twitter:@paelladev:evm",
                WalletLocator.owner(.twitter("@paelladev"), .evm)
            ),
            (
                "x:@paelladev:evm",
                WalletLocator.owner(.x("@paelladev"), .evm)
            )
        ]
    )
    func willReturnTheCorrectWalletLocatorForTheGivenType(expectAndActual: (String, WalletLocator))
        async {
        #expect(expectAndActual.0 == expectAndActual.1.value)
    }

    @Test("Can intialize from string locator")
    func canIntializeFromStringLocator() async {
        let locatorString = "0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d"
        let locator = try? WalletLocator(from: locatorString)
        #expect(locator?.value == locatorString)

        let locatorString2 = "userId:userID:evm-smart-wallet"
        let locator2 = try? WalletLocator(from: locatorString2)
        #expect(locator2?.value == locatorString2)

        let locatorString3 = "phoneNumber:555-1239:evm-smart-wallet"
        let locator3 = try? WalletLocator(from: locatorString3)
        #expect(locator3?.value == locatorString3)

        let locatorString4 = "email:test@paella.dev:base-sepolia"
        let locator4 = try? WalletLocator(from: locatorString4)
        #expect(locator4?.value == locatorString4)

        let locatorString5 = "base-sepolia:0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d"
        let locator5 = try? WalletLocator(from: locatorString5)
        #expect(locator5?.value == locatorString5)
    }
}
