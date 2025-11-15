import Payments
import SwiftUI
import Utils

struct EmbeddedCheckoutGlobalMessageView: View {
    @EnvironmentObject private var checkoutStateManager: EmbeddedCheckoutStateManager
    @State private var autoDismissTimer: Timer?
    let displayLocation: EmbeddedCheckoutGlobalMessageDisplayLocation

    // TODO use appearance manager for overall checkout appearance
    let defaultSpacing: CGFloat = 3.0

    var body: some View {
        if let globalMessage = checkoutStateManager.globalMessage,
            globalMessage.displayLocation == displayLocation {
            messageView(for: globalMessage)
                .onAppear {
                    setupTimeoutIfNeeded(for: globalMessage)
                }
        } else {
            EmptyView()
        }
    }

    private func messageView(for message: EmbeddedCheckoutGlobalMessage) -> some View {
        HStack(alignment: .top, spacing: 8) {
            messageIcon(for: message)
                .frame(width: 20, height: 20)

            Text(message.message)
                .font(.system(size: 14, weight: .medium))
                .tracking(-0.5)
                .lineSpacing(1)
                .foregroundColor(textColor(for: message))
                .multilineTextAlignment(.leading)
                .padding(.trailing, 8)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(backgroundColor(for: message))
        .cornerRadius(8)
        .padding(
            displayLocation == .top ? .bottom : .top,
            displayLocation == .top ? defaultSpacing * 3.6 : defaultSpacing * 4.8)
    }

    private func messageIcon(for message: EmbeddedCheckoutGlobalMessage) -> some View {
        switch message.type {
        case .error, .devError:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(textColor(for: message))
        case .warning:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(textColor(for: message))
        }
    }

    private func textColor(for message: EmbeddedCheckoutGlobalMessage) -> Color {
        switch message.type {
        case .error:
            return Color.red
        case .devError:
            return Color(hex: "#3C1AE8")
        case .warning:
            return Color.yellow
        }
    }

    private func backgroundColor(for message: EmbeddedCheckoutGlobalMessage) -> Color {
        switch message.type {
        case .error:
            return Color.red.opacity(0.12)
        case .devError:
            return Color(hex: "#3C1AE8").opacity(0.12)
        case .warning:
            return Color.yellow.opacity(0.12)
        }
    }

    private func setupTimeoutIfNeeded(for message: EmbeddedCheckoutGlobalMessage) {
        // Cancel any existing timer
        autoDismissTimer?.invalidate()
        autoDismissTimer = nil

        // Set up a new timer if timeout is specified
        if let timeout = message.timeout {
            let weakStateManager = checkoutStateManager
            autoDismissTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) {
                [weak weakStateManager] _ in
                DispatchQueue.main.async {
                    weakStateManager?.globalMessage = nil
                }
            }
        }
    }
}

#Preview {
    let stateManager = EmbeddedCheckoutStateManager(
        paymentMethod: .card,
        receiptEmail: nil
    )
    stateManager.globalMessage = EmbeddedCheckoutGlobalMessage(
        message: "This is an error",
        displayLocation: .top,
        type: .error,
        timeout: 10,
        fatal: false
    )
    return EmbeddedCheckoutGlobalMessageView(
        displayLocation: .top
    ).environmentObject(stateManager)
}
