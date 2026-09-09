import CrossmintCommonTypes
import Foundation

public struct WalletConfig {
    /// The first recovery signer of the wallet.
    public let recovery: AdminSignerData
    /// Every recovery signer of the wallet. Each one can authorize on its own.
    public let recoveryMethods: [AdminSignerData]

    public init(recovery: AdminSignerData, recoveryMethods: [AdminSignerData]? = nil) {
        self.recovery = recovery
        self.recoveryMethods = recoveryMethods ?? [recovery]
    }

    /// The first recovery signer of the given concrete type, if the wallet has one.
    func recoverySigner<T: AdminSignerData>(ofType type: T.Type) -> T? {
        for method in recoveryMethods {
            if let match = method as? T { return match }
        }
        return nil
    }
}
