import CrossmintService
import Logger
import Auth

public actor CrossmintClient {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var shared: ClientSDK?

    private let apiKey: String

    private init(apiKey: String) {
        self.apiKey = apiKey
    }

    public static func sdk(key: String, authManager: AuthManager? = nil) -> ClientSDK {
        lock.lock()
        defer { lock.unlock() }

        guard let shared else {
            let apiKey: ApiKey
            do {
                apiKey = try ApiKey(key: key)
            } catch {
                Logger.sdk.error("Invalid API key")
                fatalError("Invalid Crossmint API key provided: \(key)")
            }

            guard apiKey.type == .client else {
                Logger.sdk.error("API key is not a client key")
                fatalError("API key must be a client key, not a server key")
            }

            let instance = CrossmintClientSDK(apiKey: apiKey, authManager: authManager)
            shared = instance
            return instance
        }
        return shared
    }
}
