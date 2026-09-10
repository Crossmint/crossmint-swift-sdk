import CrossmintCommonTypes
import Foundation

public struct WalletConfig {
    /// Every recovery signer of the wallet. Each one can authorize on its own.
    public let recoveryMethods: [AdminSignerData]

    /// The first recovery signer of the wallet.
    public var recovery: AdminSignerData { recoveryMethods[0] }

    public init(recoveryMethods: [AdminSignerData]) {
        precondition(!recoveryMethods.isEmpty, "A wallet has at least one recovery signer")
        self.recoveryMethods = recoveryMethods
    }

    var recoveryLocators: [SignerLocator] {
        recoveryMethods.compactMap { try? SignerLocator(from: $0.locator) }
    }

    func recoverySigner<T: AdminSignerData>(ofType type: T.Type) -> T? {
        for method in recoveryMethods {
            if let match = method as? T { return match }
        }
        return nil
    }
}
