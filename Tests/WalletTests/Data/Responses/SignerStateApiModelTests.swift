import Foundation
import Testing

@testable import Wallet

private func decodeSigner(_ json: String) throws -> SignerStateApiModel {
    try JSONDecoder().decode(SignerStateApiModel.self, from: Data(json.utf8))
}

@Suite("SignerStateApiModel mapping", .tags(.unit))
struct SignerStateApiModelTests {

    @Suite("when the wallet is on an EVM chain")
    struct EVMTests {
        @Test func mapsStatusFromTheEntryMatchingTheWalletChain() throws {
            let model = try decodeSigner("""
            {
                "locator": "email:user@example.com",
                "chains": {
                    "base-sepolia": { "status": "awaiting-approval" },
                    "polygon-amoy": { "status": "success" }
                }
            }
            """)

            let signer = model.toDomain(chainType: .evm, chainName: "base-sepolia")

            #expect(signer == WalletSigner(locator: "email:user@example.com", status: .awaitingApproval))
        }

        @Test func omitsSignerWithoutEntryForTheWalletChain() throws {
            let model = try decodeSigner("""
            {
                "locator": "email:user@example.com",
                "chains": {
                    "polygon-amoy": { "status": "success" }
                }
            }
            """)

            #expect(model.toDomain(chainType: .evm, chainName: "base-sepolia") == nil)
        }

        @Test func defaultsToSuccessWhenThereAreNoChainEntries() throws {
            let model = try decodeSigner("""
            { "locator": "device:abc123", "chains": {} }
            """)

            let signer = model.toDomain(chainType: .evm, chainName: "base-sepolia")

            #expect(signer == WalletSigner(locator: "device:abc123", status: .success))
        }

        @Test func omitsSignerWithAnUnknownStatusValue() throws {
            let model = try decodeSigner("""
            {
                "locator": "email:user@example.com",
                "chains": {
                    "base-sepolia": { "status": "definitely-not-a-status" }
                }
            }
            """)

            #expect(model.toDomain(chainType: .evm, chainName: "base-sepolia") == nil)
        }
    }

    @Suite("when the wallet is on Solana")
    struct SolanaTests {
        @Test func mapsStatusFromTheRegistrationTransaction() throws {
            let model = try decodeSigner("""
            {
                "locator": "device:abc123",
                "transaction": { "status": "pending" }
            }
            """)

            let signer = model.toDomain(chainType: .solana, chainName: "solana")

            #expect(signer == WalletSigner(locator: "device:abc123", status: .pending))
        }

        @Test func defaultsToSuccessWithoutARegistrationTransaction() throws {
            let model = try decodeSigner("""
            { "locator": "device:abc123" }
            """)

            let signer = model.toDomain(chainType: .solana, chainName: "solana")

            #expect(signer == WalletSigner(locator: "device:abc123", status: .success))
        }

        @Test func defaultsToSuccessOnAnUnknownTransactionStatus() throws {
            let model = try decodeSigner("""
            {
                "locator": "device:abc123",
                "transaction": { "status": "definitely-not-a-status" }
            }
            """)

            let signer = model.toDomain(chainType: .solana, chainName: "solana")

            #expect(signer?.status == .success)
        }
    }

    @Test func fallsBackToTheLegacySignerFieldForTheLocator() throws {
        let model = try decodeSigner("""
        { "signer": "email:legacy@example.com" }
        """)

        let signer = model.toDomain(chainType: .solana, chainName: "solana")

        #expect(signer?.locator == "email:legacy@example.com")
    }

    @Test func omitsSignerWithoutAnyLocator() throws {
        let model = try decodeSigner("{}")

        #expect(model.toDomain(chainType: .solana, chainName: "solana") == nil)
    }
}
