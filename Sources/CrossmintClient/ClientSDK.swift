import CrossmintAuth
import Wallet

protocol ClientSDK {
    func crossmintWallets() -> CrossmintWallets
    var authManager: AuthManager { get }
    var isProductionEnvironment: Bool { get }
}
