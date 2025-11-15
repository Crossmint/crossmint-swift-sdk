import Logger

public struct NoOpSecureWalletStorage: SecureWalletStorage {
    public init() {
        Logger.secureStorage.warn("Secure wallet storage won't be functional. Using non-operational implementation")
    }

    public func savePrivateKey(_ privateKey: String, forEmail email: String) {
    }

    public func getPrivateKey(forEmail email: String) -> String? {
        nil
    }
}
