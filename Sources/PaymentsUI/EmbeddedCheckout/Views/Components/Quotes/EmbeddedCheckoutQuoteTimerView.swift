import Payments
import SwiftUI
import Utils

struct EmbeddedCheckoutQuoteTimerView: View {
    @EnvironmentObject private var orderManager: HeadlessCheckoutOrderManager
    @State private var countdown: Int = 0
    @State private var timer: Timer?

    // Constants for appearance
    private let fontSize: CGFloat = 12
    private let timerFontWeight: Font.Weight = .semibold
    private let textColor = Color(hex: "#67797F")
    private let thirtySeconds = 30

    private var isOrderModeExactIn: Bool {
        orderManager.order?.orderModeExactIn ?? false
    }

    private var shouldDisplay: Bool {
        guard let order = orderManager.order, isOrderModeExactIn else {
            return false
        }

        if order.lineItems.count != 1 {
            return false
        }

        // Similar to the React component, don't display for higher expiration times
        if orderManager.secondsUntilQuoteRefresh > thirtySeconds {
            return false
        }

        return true
    }

    private func calculateLineHeight(_ fontSize: CGFloat) -> CGFloat {
        return fontSize * 1.5  // Approximate line height calculation
    }

    var body: some View {
        if shouldDisplay {
            VStack {
                Group {
                    if countdown == 0 {
                        Text("Refreshing quote...")
                    } else {
                        Text("New quote in ")
                            + Text(formattedSeconds).bold()
                            + Text("s")
                    }
                }
                .font(.system(size: fontSize))
                .foregroundColor(textColor)
                .lineSpacing(calculateLineHeight(fontSize) - fontSize)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                    .padding(.top, 24)
            }
            .onAppear {
                startTimer()
            }
            .onDisappear {
                stopTimer()
            }
            .onChange(of: orderManager.secondsUntilQuoteRefresh) { newValue in
                updateCountdown(to: newValue)
            }
        } else {
            EmptyView()
        }
    }

    private var formattedSeconds: String {
        String(format: "%02d", countdown)
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async {
                if self.countdown > 0 {
                    self.countdown -= 1
                }
            }
        }

        updateCountdown(to: orderManager.secondsUntilQuoteRefresh)
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func updateCountdown(to seconds: Int) {
        countdown = seconds
        if seconds <= 0 {
            stopTimer()
        } else if timer == nil {
            startTimer()
        }
    }
}
