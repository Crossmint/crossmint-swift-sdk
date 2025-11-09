public protocol SecureWalletStorage: Sendable {
    func savePrivateKey(_ privateKey: String, forEmail email: String)
    func getPrivateKey(forEmail email: String) -> String?
}
