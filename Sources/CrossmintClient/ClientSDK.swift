import CrossmintAuth
import CrossmintService
import Wallet

protocol ClientSDK {
    func crossmintWallets() -> CrossmintWallets
    var authManager: CrossmintAuthManager { get }
    var crossmintService: CrossmintService { get }
}
