import Payments
import SwiftUI
import Wallet

struct EmbeddedCheckoutSelectedDestination: View {
    let recipientLocator: WalletLocator
    @EnvironmentObject var stateManager: EmbeddedCheckoutStateManager

    var body: some View {
        switch recipientLocator {
        case .externalWallet(let chain, let address):
            EmbeddedCheckoutSelectedWalletDestination(
                chain: chain,
                walletAddress: address
            )
        case .address(let address):
            EmbeddedCheckoutSelectedWalletDestination(
                chain: .solana,  // Defaulting to solana
                walletAddress: address
            )
        case .owner(let owner, _):
            switch owner {
            case .email(let email):
                EmbeddedCheckoutSelectedEmailDestination(email: email)
            default:
                EmptyView()
            }
        case .ownerWithChain(let owner, _):
            switch owner {
            case .email(let email):
                EmbeddedCheckoutSelectedEmailDestination(email: email)
            default:
                EmptyView()
            }
        }
    }
}
