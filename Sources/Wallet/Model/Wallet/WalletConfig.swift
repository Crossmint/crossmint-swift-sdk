import CrossmintCommonTypes
import Foundation

public struct WalletConfig {
    let recoveryMethodsWithStatus: [RecoveryMethod]

    /// Every recovery signer of the wallet. Each one can authorize on its own.
    public var recoveryMethods: [AdminSignerData] { recoveryMethodsWithStatus.map(\.signer) }

    /// The first recovery signer of the wallet.
    public var recovery: AdminSignerData { recoveryMethodsWithStatus[0].signer }

    init(recovery: RecoveryMethod, others: [RecoveryMethod] = []) {
        recoveryMethodsWithStatus = [recovery] + others
    }

    init(recovery: AdminSignerData) {
        self.init(recovery: RecoveryMethod(signer: recovery))
    }

    func recoverySigner<T: AdminSignerData>(ofType type: T.Type) -> T? {
        for method in recoveryMethods {
            if let match = method as? T { return match }
        }
        return nil
    }
}
