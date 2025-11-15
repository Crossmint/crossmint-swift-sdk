import Payments
import SwiftUI

struct EmbeddedFatalErrorGuardView<Content: View>: View {
    @EnvironmentObject var checkoutStateManager: EmbeddedCheckoutStateManager
    let content: Content
    var dimmed: Bool {
        return checkoutStateManager.globalMessage?.fatal ?? false
    }

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .overlay(
                Group {
                    if dimmed {
                        Color.white  // TODO: Use theme color from appearance manager
                            .opacity(0.6)
                            .allowsHitTesting(true)  // blocking interaction with content below on fatal error
                    }
                }
            )
    }
}

#Preview {
    let checkoutStateManager = EmbeddedCheckoutStateManager(
        paymentMethod: EmbeddedCheckoutLocalPaymentMethod.card,
        receiptEmail: nil
    )

    checkoutStateManager.globalMessage = EmbeddedCheckoutGlobalMessage(
        message: "Fatal error",
        displayLocation: .top,
        type: .error,
        fatal: true
    )

    return VStack(spacing: 50) {
        Text("Not dimmed")

        EmbeddedFatalErrorGuardView {
            Text("Dimmed!")
        }

        Text("Not dimmed")
    }
    .environmentObject(checkoutStateManager)
}
