import CrossmintCommonTypes
import Foundation

public struct WalletConfig {
    /// Every recovery signer of the wallet. Each one can authorize on its own.
    public let recoveryMethods: [AdminSignerData]

    let recoveryMethodStatuses: [String: SignerStatus]

    /// The first recovery signer of the wallet.
    public var recovery: AdminSignerData { recoveryMethods[0] }

    init(recovery: AdminSignerData, others: [AdminSignerData] = [], statuses: [String: SignerStatus] = [:]) {
        recoveryMethods = [recovery] + others
        recoveryMethodStatuses = statuses
    }

    func recoverySigner<T: AdminSignerData>(ofType type: T.Type) -> T? {
        for method in recoveryMethods {
            if let match = method as? T { return match }
        }
        return nil
    }
}
