import CrossmintCommonTypes
import Foundation

public struct WalletConfig {
    /// Every recovery signer of the wallet. Each one can authorize on its own.
    public let recoveryMethods: [AdminSignerData]

    private let recoveryMethodStatuses: [SignerLocator: SignerStatus]

    /// The first recovery signer of the wallet.
    public var recovery: AdminSignerData { recoveryMethods[0] }

    init(recovery: AdminSignerData, others: [AdminSignerData] = [], statuses: [SignerLocator: SignerStatus] = [:]) {
        recoveryMethods = [recovery] + others
        recoveryMethodStatuses = statuses
    }

    func recoveryMethodStatus(for locator: SignerLocator) -> SignerStatus? {
        recoveryMethodStatuses[locator]
    }

    func recoverySigner<T: AdminSignerData>(ofType type: T.Type) -> T? {
        for method in recoveryMethods {
            if let match = method as? T { return match }
        }
        return nil
    }
}
