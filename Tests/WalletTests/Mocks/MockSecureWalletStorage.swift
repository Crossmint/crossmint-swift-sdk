import SecureStorage

final class MockSecureWalletStorage: SecureWalletStorage, @unchecked Sendable {
    func savePrivateKey(_ privateKey: String, forEmail email: String) {}
    func getPrivateKey(forEmail email: String) -> String? { nil }
}
