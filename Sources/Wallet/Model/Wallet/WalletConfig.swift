import CrossmintCommonTypes
import Foundation

public struct WalletConfig {
    /// Every recovery signer of the wallet. Each one can authorize on its own.
    public let recoveryMethods: [AdminSignerData]

    /// The first recovery signer of the wallet.
    public var recovery: AdminSignerData { recoveryMethods[0] }

    init(recovery: AdminSignerData, others: [AdminSignerData] = []) {
        recoveryMethods = [recovery] + others
    }

    func recoverySigner<T: AdminSignerData>(ofType type: T.Type) -> T? {
        for method in recoveryMethods {
            if let match = method as? T { return match }
        }
        return nil
    }

    func containsRecoveryMethod(_ locator: SignerLocator) -> Bool {
        recoveryMethods.contains { (try? SignerLocator(from: $0.locator)) == locator }
    }
}
