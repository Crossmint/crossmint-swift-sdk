import CrossmintAuth
import CrossmintService
import Wallet

protocol ClientSDK {
    func crossmintWallets() -> CrossmintWallets
    var authManager: CrossmintAuthManager { get }
    var authClient: any AuthClient { get }
    var crossmintService: CrossmintService { get }
}
