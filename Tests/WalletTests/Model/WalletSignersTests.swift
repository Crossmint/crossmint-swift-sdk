import CrossmintCommonTypes
import Foundation
import Testing
import TestsUtils

@testable import Wallet

private let DEVICE_PUBLIC_KEY = "8Ht1jWbGgXcDqFv3nRkPzYw5mT2uLsEaK9oC4dNbV6xJ"
private let DEVICE_LOCATOR = "device:\(DEVICE_PUBLIC_KEY)"
private let EMAIL = "delegate@example.com"
private let EMAIL_LOCATOR = "email:\(EMAIL)"

private func makeSolanaWallet(
    walletService: MockSmartWalletService,
    fixture: String = "WalletSolanaSigners"
) throws -> SolanaWallet {
    let baseModel: WalletApiModel = try GetFromFile.getModelFrom(
        fileName: fixture,
        bundle: Bundle.module
    )
    walletService.getWalletResult = baseModel
    return try SolanaWallet(
        smartWalletService: walletService,
        signer: MockSigner(),
        baseModel: baseModel,
        solanaChain: .solana,
        onTransactionStart: nil
    )
}

private func makeEVMWallet(walletService: MockSmartWalletService) throws -> EVMWallet {
    let baseModel: WalletApiModel = try GetFromFile.getModelFrom(
        fileName: "WalletEVMSigners",
        bundle: Bundle.module
    )
    walletService.getWalletResult = baseModel
    return try EVMWallet(
        smartWalletService: walletService,
        signer: MockSigner(),
        baseModel: baseModel,
        evmChain: .baseSepolia,
        onTransactionStart: nil
    )
}

private func solanaRegistration(status: String?) -> AddDelegatedSignerResponse {
    AddDelegatedSignerResponse(
        chains: nil,
        transaction: RegistrationTransaction(id: "tx-1", status: status)
    )
}

@Suite("Wallet signers", .tags(.unit))
struct WalletSignersTests {

    @Test func returnsEachSignerWithItsStatusInConfigOrder() async throws {
        let walletService = MockSmartWalletService()
        walletService.getSignerResponses = [
            DEVICE_LOCATOR: solanaRegistration(status: nil),
            EMAIL_LOCATOR: solanaRegistration(status: "pending")
        ]
        // The first locator's lookup is held until the second completes, so the
        // returned list must restore the config order, not the completion order.
        walletService.getSignerGatedLocator = DEVICE_LOCATOR
        let wallet = try makeSolanaWallet(walletService: walletService)

        let signers = try await wallet.signers()

        #expect(signers == [
            WalletSigner(locator: .device(publicKey: DEVICE_PUBLIC_KEY), status: .active),
            WalletSigner(locator: .email(EMAIL), status: .pending)
        ])
    }

    @Test func makesOneWalletRequestAndOneStateLookupPerSigner() async throws {
        let walletService = MockSmartWalletService()
        let wallet = try makeSolanaWallet(walletService: walletService)

        _ = try await wallet.signers()

        #expect(walletService.getWalletCallCount == 1)
        #expect(walletService.getSignerCallCount == 2)
        #expect(Set(walletService.getSignerLocators) == [DEVICE_LOCATOR, EMAIL_LOCATOR])
    }

    @Test func returnsUnknownStatusForSignersWhoseStateLookupFails() async throws {
        let walletService = MockSmartWalletService()
        walletService.getSignerResponses = [
            EMAIL_LOCATOR: solanaRegistration(status: "active")
        ]
        walletService.getSignerErrorLocators = [DEVICE_LOCATOR]
        let wallet = try makeSolanaWallet(walletService: walletService)

        let signers = try await wallet.signers()

        #expect(signers == [
            WalletSigner(locator: .device(publicKey: DEVICE_PUBLIC_KEY), status: .unknown),
            WalletSigner(locator: .email(EMAIL), status: .active)
        ])
    }

    @Test func returnsUnknownStatusForSignersTheStateEndpointDoesNotFind() async throws {
        let walletService = MockSmartWalletService()
        walletService.getSignerResult = nil
        walletService.getSignerResponses = [
            EMAIL_LOCATOR: solanaRegistration(status: "active")
        ]
        let wallet = try makeSolanaWallet(walletService: walletService)

        let signers = try await wallet.signers()

        #expect(signers == [
            WalletSigner(locator: .device(publicKey: DEVICE_PUBLIC_KEY), status: .unknown),
            WalletSigner(locator: .email(EMAIL), status: .active)
        ])
    }

    @Test func returnsEmptyListForAWalletWithoutSigners() async throws {
        let walletService = MockSmartWalletService()
        let wallet = try makeSolanaWallet(walletService: walletService, fixture: "WalletSolanaEmail")

        let signers = try await wallet.signers()

        #expect(signers.isEmpty)
        #expect(walletService.getSignerCallCount == 0)
    }

    @Test func rethrowsTheErrorWhenTheWalletFetchFails() async throws {
        let walletService = MockSmartWalletService()
        let wallet = try makeSolanaWallet(walletService: walletService)
        walletService.getWalletError = .walletGeneric("wallet fetch exploded")

        await #expect(throws: WalletError.self) {
            try await wallet.signers()
        }
    }

    @Suite("when the wallet is on an EVM chain")
    struct EVMTests {
        @Test func omitsSignersWithoutRegistrationForTheWalletChain() async throws {
            let walletService = MockSmartWalletService()
            walletService.getSignerResponses = [
                DEVICE_LOCATOR: AddDelegatedSignerResponse(
                    chains: ["base-sepolia": ChainRegistrationEntry(id: "1", status: .active, approvals: nil)],
                    transaction: nil
                ),
                EMAIL_LOCATOR: AddDelegatedSignerResponse(
                    chains: ["polygon-amoy": ChainRegistrationEntry(id: "2", status: .active, approvals: nil)],
                    transaction: nil
                )
            ]
            let wallet = try makeEVMWallet(walletService: walletService)

            let signers = try await wallet.signers()

            #expect(signers == [WalletSigner(locator: .device(publicKey: DEVICE_PUBLIC_KEY), status: .active)])
        }

        @Test func mapsTheStatusFromTheEntryMatchingTheWalletChain() async throws {
            let walletService = MockSmartWalletService()
            walletService.getSignerResponses = [
                DEVICE_LOCATOR: AddDelegatedSignerResponse(
                    chains: [
                        "base-sepolia": ChainRegistrationEntry(id: "1", status: .awaitingApproval, approvals: nil),
                        "polygon-amoy": ChainRegistrationEntry(id: "2", status: .active, approvals: nil)
                    ],
                    transaction: nil
                ),
                EMAIL_LOCATOR: AddDelegatedSignerResponse(chains: [:], transaction: nil)
            ]
            let wallet = try makeEVMWallet(walletService: walletService)

            let signers = try await wallet.signers()

            #expect(signers == [
                WalletSigner(locator: .device(publicKey: DEVICE_PUBLIC_KEY), status: .awaitingApproval),
                WalletSigner(locator: .email(EMAIL), status: .active)
            ])
        }
    }
}
