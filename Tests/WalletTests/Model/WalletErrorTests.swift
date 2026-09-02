import CrossmintService
import Testing

@testable import Wallet

struct WalletErrorTests {

    // MARK: - WalletError

    @Test("WalletError.walletNotFound has expected code and recovery suggestion")
    func walletNotFound() {
        let error = WalletError.walletNotFound
        #expect(error.code == "WALLET_NOT_FOUND")
        #expect(error.message == "Wallet not found")
        #expect(error.recoverySuggestion == "Create a wallet using wallets.getOrCreate(chain:signer:)")
        #expect(error.underlyingError == nil)
    }

    @Test("WalletError.walletCreationFailed carries reason in message")
    func walletCreationFailed() {
        let error = WalletError.walletCreationFailed("timeout")
        #expect(error.code == "WALLET_CREATION_FAILED")
        #expect(error.message == "timeout")
        #expect(error.recoverySuggestion == nil)
    }

    @Test("WalletError.signerNotRegistered has recovery suggestion")
    func signerNotRegistered() {
        let error = WalletError.signerNotRegistered("0xabc")
        #expect(error.code == "SIGNER_NOT_REGISTERED")
        #expect(error.recoverySuggestion == "Call addSigner before attempting operations that require this signer.")
        #expect(error.underlyingError == nil)
    }

    @Test("WalletError.signerLocatorError carries the invalid locator in message")
    func signerLocatorError() {
        let error = WalletError.signerLocatorError("carrier-pigeon:0xabc")
        #expect(error.code == "SIGNER_LOCATOR_ERROR")
        #expect(error.message.contains("carrier-pigeon:0xabc"))
        #expect(error.recoverySuggestion != nil)
    }

    @Test("WalletError.serviceError wraps underlying error")
    func serviceError() {
        let inner = CrossmintServiceError.invalidApiKey("bad-key")
        let error = WalletError.serviceError(inner)
        #expect(error.code == "SERVICE_ERROR")
        #expect(error.message == inner.message)
        #expect(error.underlyingError != nil)
    }

    @Test("WalletError conforms to CrossmintError and description is formatted")
    func descriptionFormat() {
        let error = WalletError.walletNotFound
        let desc = error.description
        #expect(desc.contains("[WALLET_NOT_FOUND]"))
        #expect(desc.contains("Wallet not found"))
        #expect(desc.contains("Recovery:"))
    }

    // MARK: - TransactionError

    @Test("TransactionError.transactionNotFound has expected code")
    func transactionNotFound() {
        let error = TransactionError.transactionNotFound
        #expect(error.code == "TRANSACTION_NOT_FOUND")
        #expect(error.message == "Transaction not found")
    }

    @Test("TransactionError.userCancelled has no recovery suggestion")
    func userCancelled() {
        let error = TransactionError.userCancelled
        #expect(error.code == "USER_CANCELLED")
        #expect(error.recoverySuggestion == nil)
    }

    @Test("TransactionError.transactionSigningFailed exposes underlying error")
    func transactionSigningFailed() {
        let inner = CrossmintServiceError.timeout
        let error = TransactionError.transactionSigningFailed(inner)
        #expect(error.code == "TRANSACTION_SIGNING_FAILED")
        #expect(error.underlyingError != nil)
    }

    @Test("TransactionError.invalidApprovals includes counts in message")
    func invalidApprovals() {
        let error = TransactionError.invalidApprovals(expected: 2, actual: 1)
        #expect(error.code == "INVALID_APPROVALS")
        #expect(error.message.contains("2"))
        #expect(error.message.contains("1"))
    }

    // MARK: - SignatureError

    @Test("SignatureError.creationFailed has expected code")
    func signatureCreationFailed() {
        let error = SignatureError.creationFailed
        #expect(error.code == "SIGNATURE_CREATION_FAILED")
        #expect(error.recoverySuggestion == nil)
    }

    @Test("SignatureError.serviceError exposes underlying error")
    func signatureServiceError() {
        let inner = CrossmintServiceError.unknown
        let error = SignatureError.serviceError(inner)
        #expect(error.underlyingError != nil)
    }
}
