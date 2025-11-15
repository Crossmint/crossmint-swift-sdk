import CrossmintCommonTypes
import SwiftUI
import Utils

struct EmbeddedCheckoutSelectedWalletDestination: View {
    let chain: Chain
    let walletAddress: Address

    // TODO use localization
    var body: some View {
        EmbeddedCheckoutSelectedDestinationTemplate(
            icon: Image("crypto", bundle: .module),  // TODO icon are svgs. Need a svg renderer
            title: "\(chain.name) Wallet",
            subTitle: cutMiddleAndAddEllipsis(walletAddress.description, beginLength: 6, endLength: 6)
        )
    }
}
