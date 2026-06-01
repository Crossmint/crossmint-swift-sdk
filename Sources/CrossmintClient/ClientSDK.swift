import CrossmintAuth
import CrossmintService
import Wallet

protocol ClientSDK {
    func crossmintWallets() -> CrossmintWallets
    var authManager: CrossmintAuthManager { get }
    var authClient: AuthClient { get }
    var crossmintService: CrossmintService { get }
}
