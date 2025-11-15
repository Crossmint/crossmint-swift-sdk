import Payments
import SwiftUI

struct EmbeddedCheckoutOpenInCrossmintButton: View {
    @EnvironmentObject var orderManager: HeadlessCheckoutOrderManager
    @Environment(\.openURL) private var openURL

    var link: String {
        // TODO change when backend link changes
        let walletUrl =
            orderManager.order?.isMultiTokenOrder ?? false ? "/user/collection" : "/user/collection"
        return
            "/signin?callbackUrl=\(walletUrl)&email=\(orderManager.order?.payment.receiptEmail ?? "")"
    }

    var isCrossmintRecipient: Bool {
        guard let recipient = orderManager.order?.lineItemDeliveryRecipient else {
            return false
        }
        return recipient.email != nil
    }

    // TODO use appearance manager
    var body: some View {
        if !isCrossmintRecipient {
            EmptyView()
        } else {
            Button {
                if let url = URL(string: "https://www.crossmint.com" + link) {
                    openURL(url)
                }
            } label: {
                Text("View purchase")
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .frame(height: 50)
                    .cornerRadius(12)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: "05B959"))
            .padding(.top, 32)
        }
    }
}
