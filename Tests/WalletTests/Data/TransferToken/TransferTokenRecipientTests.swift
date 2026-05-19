import CrossmintCommonTypes
import Foundation
import Testing
import Utils

@testable import Wallet

struct TransferTokenRecipientTest {
    // swiftlint:disable:next force_try
    private let someEVMAddress = try! EVMAddress(
        address: "0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d"
    )

    @Test("ChainAddress case creates correct description")
    func chainAddressCaseCreatesCorrectDescription() async {
        let address = someEVMAddress.address

        let recipient = TransferTokenRecipient.address(.evm(.ethereum, someEVMAddress))

        #expect(recipient == "ethereum:\(address)")
    }

    @Test("Email case with chain creates correct description")
    func emailCaseWithChainCreatesCorrectDescription() async {
        // swiftlint:disable:next force_unwrapping
        let email = "test@example.com".asNonEmptyString!
        let chain = Chain.solana

        let recipient = TransferTokenRecipient.email(.withChain(email, chain: chain))

        #expect(recipient == "email:\(email):solana")
    }

    @Test("Email case without chain creates correct description")
    func emailCaseWithoutChainCreatesCorrectDescription() async {
        // swiftlint:disable:next force_unwrapping
        let email = "test@example.com".asNonEmptyString!

        let recipient = TransferTokenRecipient.email(.just(email))

        #expect(recipient == "email:\(email)")
    }

    @Test("PhoneNumber case with chain creates correct description")
    func phoneNumberCaseWithChainCreatesCorrectDescription() async {
        // swiftlint:disable:next force_unwrapping
        let phoneNumber = "+1234567890".asNonEmptyString!

        let recipient = TransferTokenRecipient.phoneNumber(.withChain(phoneNumber, chain: .polygon))

        #expect(recipient == "phoneNumber:\(phoneNumber):polygon")
    }

    @Test("PhoneNumber case without chain creates correct description")
    func phoneNumberCaseWithoutChainCreatesCorrectDescription() async {
        // swiftlint:disable:next force_unwrapping
        let phoneNumber = "+1234567890".asNonEmptyString!

        let recipient = TransferTokenRecipient.phoneNumber(.just(phoneNumber))

        #expect(recipient == "phoneNumber:\(phoneNumber)")
    }

    @Test("Twitter case with chain creates correct description")
    func twitterCaseWithChainCreatesCorrectDescription() async {
        // swiftlint:disable:next force_unwrapping
        let handle = "crossmint".asNonEmptyString!
        let chain = Chain.solana

        let recipient = TransferTokenRecipient.twitter(.withChain(handle, chain: chain))

        #expect(recipient == "twitter:\(handle):solana")
    }

    @Test("Twitter case without chain creates correct description")
    func twitterCaseWithoutChainCreatesCorrectDescription() async {
        // swiftlint:disable:next force_unwrapping
        let handle = "crossmint".asNonEmptyString!

        let recipient = TransferTokenRecipient.twitter(.just(handle))

        #expect(recipient == "twitter:\(handle)")
    }

    @Test("X case with chain creates correct description")
    func xCaseWithChainCreatesCorrectDescription() async {
        // swiftlint:disable:next force_unwrapping
        let handle = "crossmint".asNonEmptyString!
        let chain = Chain.solana

        let recipient = TransferTokenRecipient.x(.withChain(handle, chain: chain))

        #expect(recipient == "x:\(handle):solana")
    }

    @Test("X case without chain creates correct description")
    func xCaseWithoutChainCreatesCorrectDescription() async {
        // swiftlint:disable:next force_unwrapping
        let handle = "crossmint".asNonEmptyString!

        let recipient = TransferTokenRecipient.x(.just(handle))

        #expect(recipient == "x:\(handle)")
    }

    @Test("UserId case with chain creates correct description")
    func userIdCaseWithChainCreatesCorrectDescription() async {
        // swiftlint:disable:next force_unwrapping
        let userId = "user123456".asNonEmptyString!
        let chain = Chain.solana

        let recipient = TransferTokenRecipient.userId(.withChain(userId, chain: chain))

        #expect(recipient == "userId:\(userId):solana")
    }

    @Test("UserId case without chain creates correct description")
    func userIdCaseWithoutChainCreatesCorrectDescription() async {
        // swiftlint:disable:next force_unwrapping
        let userId = "user123456".asNonEmptyString!

        let recipient = TransferTokenRecipient.userId(.just(userId))

        #expect(recipient == "userId:\(userId)")
    }

    @Test("Matches method returns true for exact match")
    func matchesMethodReturnsTrueForExactMatch() async {
        // swiftlint:disable:next force_unwrapping
        let email = "test@example.com".asNonEmptyString!
        let recipient = TransferTokenRecipient.email(.just(email))

        #expect(recipient.matches("email:\(email)"))
        #expect(recipient.matches(recipient.description))
    }

    @Test("Matches method returns false for non-match")
    func matchesMethodReturnsFalseForNonMatch() async {
        // swiftlint:disable:next force_unwrapping
        let email = "test@example.com".asNonEmptyString!
        let recipient = TransferTokenRecipient.email(.just(email))

        #expect(!recipient.matches("different string"))
        #expect(!recipient.matches("email:other@example.com"))
    }

    @Test("String equality operators work correctly")
    func stringEqualityOperatorsWorkCorrectly() async {
        let recipient = TransferTokenRecipient.address(.evm(.ethereum, someEVMAddress))

        let expectedRecipient = "ethereum:\(someEVMAddress.address)"
        #expect(recipient == expectedRecipient)
        #expect(expectedRecipient == recipient)
        #expect(!(recipient != expectedRecipient))
        #expect(!(expectedRecipient != recipient))

        let differentString = "different"
        #expect(!(recipient == differentString))
        #expect(!(differentString == recipient))
        #expect(recipient != differentString)
        #expect(differentString != recipient)
    }

    @Test("Handles special characters in values")
    func handlesSpecialCharactersInValues() async {
        // swiftlint:disable:next force_unwrapping
        let specialEmail = "test+tag@example.com".asNonEmptyString!
        // swiftlint:disable:next force_unwrapping
        let specialHandle = "user_123".asNonEmptyString!

        let emailRecipient = TransferTokenRecipient.email(.just(specialEmail))
        #expect(emailRecipient == "email:\(specialEmail)")

        let twitterRecipient = TransferTokenRecipient.twitter(.just(specialHandle))
        #expect(twitterRecipient == "twitter:\(specialHandle)")
    }

    @Test("Handles unicode characters in values")
    func handlesUnicodeCharactersInValues() async {
        // swiftlint:disable:next force_unwrapping
        let unicodeEmail = "测试@example.com".asNonEmptyString!
        // swiftlint:disable:next force_unwrapping
        let unicodeHandle = "用户🚀".asNonEmptyString!
        let chain = Chain.ethereum

        let emailRecipient = TransferTokenRecipient.email(.withChain(unicodeEmail, chain: chain))
        #expect(emailRecipient == "email:\(unicodeEmail):ethereum")

        let xRecipient = TransferTokenRecipient.x(.withChain(unicodeHandle, chain: chain))
        #expect(xRecipient == "x:\(unicodeHandle):ethereum")
    }

    @Test("Real-world email scenario")
    func realWorldEmailScenario() async {
        // swiftlint:disable:next force_unwrapping
        let email = "user@crossmint.com".asNonEmptyString!
        let chain = Chain.ethereum

        let recipient = TransferTokenRecipient.email(.withChain(email, chain: chain))

        #expect(recipient == "email:\(email):ethereum")
        #expect(recipient.matches("email:\(email):ethereum"))
    }

    @Test("Real-world wallet address scenario")
    func realWorldWalletAddressScenario() async {
        let recipient = TransferTokenRecipient.address(.evm(.ethereum, someEVMAddress))

        #expect(recipient == "ethereum:\(someEVMAddress.address)")
    }

    @Test("Real-world phone number scenario")
    func realWorldPhoneNumberScenario() async {
        // swiftlint:disable:next force_unwrapping
        let phoneNumber = "+1-555-123-4567".asNonEmptyString!
        let chain = Chain.solana

        let recipient = TransferTokenRecipient.phoneNumber(.withChain(phoneNumber, chain: chain))

        #expect(recipient == "phoneNumber:\(phoneNumber):solana")
    }

    @Test("Same user on different chains produces different descriptions")
    func sameUserOnDifferentChainsProducesDifferentDescriptions() async {
        // swiftlint:disable:next force_unwrapping
        let email = "user@example.com".asNonEmptyString!
        let ethereumChain = Chain.ethereum
        let polygonChain = Chain.polygon

        let ethereumRecipient = TransferTokenRecipient.email(.withChain(email, chain: ethereumChain))
        let polygonRecipient = TransferTokenRecipient.email(.withChain(email, chain: polygonChain))

        #expect(ethereumRecipient == "email:\(email):ethereum")
        #expect(polygonRecipient == "email:\(email):polygon")
        #expect(ethereumRecipient != polygonRecipient)
    }

    @Test("Description generation is consistent across multiple calls")
    func descriptionGenerationIsConsistentAcrossMultipleCalls() async {
        // swiftlint:disable:next force_unwrapping
        let email = "test@example.com".asNonEmptyString!
        let chain = Chain.ethereum
        let recipient = TransferTokenRecipient.email(.withChain(email, chain: chain))

        let firstCall = recipient
        let secondCall = recipient
        let thirdCall = recipient

        #expect(firstCall == secondCall)
        #expect(secondCall == thirdCall)
        #expect(firstCall == "email:\(email):ethereum")
    }

    @Test("ChainAddress format follows expected pattern")
    func chainAddressFormatFollowsExpectedPattern() async {
        let recipient = TransferTokenRecipient.address(.evm(.base, someEVMAddress))

        let components = recipient.description.components(separatedBy: ":")
        #expect(components.count == 2)
        #expect(components[0] == Chain.base.name)
        #expect(components[1] == someEVMAddress.address)
    }

    @Test("Email with chain format follows expected pattern")
    func emailWithChainFormatFollowsExpectedPattern() async {
        // swiftlint:disable:next force_unwrapping
        let email = "test@example.com".asNonEmptyString!
        let chain = Chain.arbitrum

        let recipient = TransferTokenRecipient.email(.withChain(email, chain: chain))

        let components = recipient.description.components(separatedBy: ":")
        #expect(components.count == 3)
        #expect(components[0] == "email")
        #expect(components[1] == email)
        #expect(components[2] == chain.name)
    }

    @Test("Email without chain format follows expected pattern")
    func emailWithoutChainFormatFollowsExpectedPattern() async {
        // swiftlint:disable:next force_unwrapping
        let email = "test@example.com".asNonEmptyString!

        let recipient = TransferTokenRecipient.email(.just(email))

        let components = recipient.description.components(separatedBy: ":")
        #expect(components.count == 2)
        #expect(components[0] == "email")
        #expect(components[1] == email)
    }

    @Test("All social handle types work correctly")
    func allSocialHandleTypesWorkCorrectly() async {
        // swiftlint:disable:next force_unwrapping
        let handle = "testuser".asNonEmptyString!

        let twitterRecipient = TransferTokenRecipient.twitter(.withChain(handle, chain: .ethereum))
        #expect(twitterRecipient == "twitter:\(handle):ethereum")

        let xRecipient = TransferTokenRecipient.x(.withChain(handle, chain: .ethereum))
        #expect(xRecipient == "x:\(handle):ethereum")

        let twitterNoChain = TransferTokenRecipient.twitter(.just(handle))
        #expect(twitterNoChain == "twitter:\(handle)")

        let xNoChain = TransferTokenRecipient.x(.just(handle))
        #expect(xNoChain == "x:\(handle)")
    }

    @Test("Equatable and Hashable work correctly")
    func equatableAndHashableWorkCorrectly() async {
        let email1 = TransferTokenRecipient.email(.withChain("test@example.com", chain: .solana))
        let email2 = TransferTokenRecipient.email(.withChain("test@example.com", chain: .solana))
        let email3 = TransferTokenRecipient.email(.withChain("different@example.com", chain: .solana))

        #expect(email1 == email2)
        #expect(email1 != email3)
        #expect(email1.hashValue == email2.hashValue)

        let set: Set<TransferTokenRecipient> = [email1, email2, email3]
        #expect(set.count == 2)
    }
}
