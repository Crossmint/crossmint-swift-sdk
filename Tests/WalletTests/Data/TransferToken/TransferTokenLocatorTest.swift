import CrossmintCommonTypes
import Foundation
import Testing

@testable import Wallet

struct TransferTokenLocatorTest {
    // swiftlint:disable:next force_try
    private let someSolanaAddress = try! SolanaAddress(
        address: "J22yK97UmV7CBa1uPkjohLWHXugx6vsaS3hUaPUPbMfu"
    )
    // swiftlint:disable:next force_try
    private let someEVMAddress = try! EVMAddress(
        address: "0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d"
    )

    @Test("TokenID case creates correct locator")
    func tokenIdCaseCreatesCorrectLocator() async {
        let tokenId = "12345"

        let locator = TransferTokenLocator.tokenId(.solana(someSolanaAddress), tokenId: tokenId)

        #expect(locator == "solana:\(someSolanaAddress.address):\(tokenId)")
    }

    @Test("Currency case creates correct locator")
    func currencyCaseCreatesCorrectLocator() async {
        let chain: EVMChain = .ethereum
        let currency = CryptoCurrency.eth

        let locator = TransferTokenLocator.currency(.evm(chain, currency))

        #expect(locator == "ethereum:\(currency.name)")
    }

    @Test("Address case creates correct locator")
    func addressCaseCreatesCorrectLocator() async {
        let locator = TransferTokenLocator.address(.evm(.polygon, someEVMAddress))

        #expect(locator == "polygon:\(someEVMAddress.address)")
    }

    @Test("Solana scenario")
    func solanaScenario() async {
        #expect(TransferTokenLocator.currency(.solana(.sol)) == "solana:sol")
    }

    @Test("Same token on different chains produces different locators")
    func sameTokenOnDifferentChainsProducesDifferentLocators() async {
        let ethereumLocator = TransferTokenLocator.address(.evm(.ethereum, someEVMAddress))
        let polygonLocator = TransferTokenLocator.address(.evm(.polygon, someEVMAddress))

        #expect(ethereumLocator == "ethereum:\(someEVMAddress.address)")
        #expect(polygonLocator == "polygon:\(someEVMAddress.address)")
        #expect(ethereumLocator != polygonLocator)
    }

    @Test("String value generation is consistent across multiple calls")
    func stringValueGenerationIsConsistentAcrossMultipleCalls() async {
        let tokenId = "999"

        let locator = TransferTokenLocator.tokenId(.evm(.ethereum, someEVMAddress), tokenId: tokenId)

        let firstCall = locator
        let secondCall = locator
        let thirdCall = locator

        #expect(firstCall == secondCall)
        #expect(secondCall == thirdCall)
        #expect(firstCall == "ethereum:\(someEVMAddress.address):\(tokenId)")
    }

    @Test("TokenID format follows expected pattern")
    func tokenIdFormatFollowsExpectedPattern() async {
        let chain: EVMChain = .ethereum
        let tokenId = "12345"

        let locator = TransferTokenLocator.tokenId(.evm(chain, someEVMAddress), tokenId: tokenId)
        let stringValue = locator.description

        let components = stringValue.components(separatedBy: ":")
        #expect(components.count == 3)
        #expect(components[0] == chain.name)
        #expect(components[1] == someEVMAddress.address)
        #expect(components[2] == tokenId)
    }

    @Test("Currency format follows expected pattern")
    func currencyFormatFollowsExpectedPattern() async {
        let chain: EVMChain = .arbitrum
        let currency = CryptoCurrency.unknown("ARB")

        let locator = TransferTokenLocator.currency(.evm(chain, currency))
        let stringValue = locator.description

        let components = stringValue.components(separatedBy: ":")
        #expect(components.count == 2)
        #expect(components[0] == chain.name)
        #expect(components[1] == currency.name)
    }

    @Test("Address format follows expected pattern")
    func addressFormatFollowsExpectedPattern() async {
        let chain: EVMChain = .optimism

        let locator = TransferTokenLocator.address(.evm(chain, someEVMAddress))
        let stringValue = locator.description

        let components = stringValue.components(separatedBy: ":")
        #expect(components.count == 2)
        #expect(components[0] == chain.name)
        #expect(components[1] == someEVMAddress.address)
    }

    @Test("Known CryptoCurrency values work correctly")
    func knownCryptoCurrencyValuesWorkCorrectly() async {
        let chain: EVMChain = .ethereum

        let ethLocator = TransferTokenLocator.currency(.evm(chain, .eth))
        #expect(ethLocator == "ethereum:eth")

        let usdcLocator = TransferTokenLocator.currency(.evm(chain, .usdc))
        #expect(usdcLocator == "ethereum:usdc")

        let solLocator = TransferTokenLocator.currency(.solana(.sol))
        #expect(solLocator == "solana:sol")
    }
}
