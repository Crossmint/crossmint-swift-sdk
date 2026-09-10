import CrossmintCommonTypes
import Foundation

public struct WalletConfig {
    /// The first recovery signer of the wallet.
    public let recovery: AdminSignerData

    /// Every recovery signer of the wallet. Each one can authorize on its own.
    public var recoveryMethods: [AdminSignerData] { [recovery] + otherRecoveryMethods }

    let otherRecoveryMethods: [AdminSignerData]

    init(recovery: AdminSignerData, otherRecoveryMethods: [AdminSignerData] = []) {
        self.recovery = recovery
        self.otherRecoveryMethods = otherRecoveryMethods
    }

    func recoverySigner<T: AdminSignerData>(ofType type: T.Type) -> T? {
        for method in recoveryMethods {
            if let match = method as? T { return match }
        }
        return nil
    }
}
