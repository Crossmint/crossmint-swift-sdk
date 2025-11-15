import Payments
import SwiftUI

struct EmbeddedCheckoutFooter: View {
    @EnvironmentObject var orderManager: HeadlessCheckoutOrderManager
    var body: some View {
        VStack {
            if orderManager.order == nil {
                EmptyView()
            } else {
                EmbeddedFatalErrorGuardView {
                    EmbeddedCheckoutTermsOfServiceView()
                }
            }
        }
    }
}
