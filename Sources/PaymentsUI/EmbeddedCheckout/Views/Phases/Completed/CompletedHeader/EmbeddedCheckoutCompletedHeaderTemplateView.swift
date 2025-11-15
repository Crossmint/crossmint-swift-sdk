import Payments
import SwiftUI
import Utils

// TODO implement
struct EmbeddedCheckoutCompletedHeaderTemplateView: View {
    let icon: Image?
    let headerText: String
    let subtitleText: String?
    let secondarySubitleText: String?

    // Constants for font sizes - these would come from AppearanceManager in the future
    private let fontSize: CGFloat = 24  // 6 * base size
    private let subtitleFontSize: CGFloat = 18  // 4.5 * base size
    private let secondarySubtitleFontSize: CGFloat = 14  // 3.5 * base size

    // Colors - these would come from AppearanceManager in the future
    private let textPrimaryColor = Color(hex: "#00150D")  // Text primary color
    private let accentColor = Color(hex: "#05B959")  // Accent color for subtitle
    private let secondaryTextColor = Color(hex: "#A4AFB2")  // Color for secondary subtitle

    private func calculateLineHeight(_ fontSize: CGFloat) -> CGFloat {
        return fontSize * 1.3  // Approximate line height calculation
    }

    var body: some View {
        VStack(spacing: 8) {
            if let icon = icon {
                icon
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
            }

            VStack(spacing: 4) {
                Text(headerText)
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundColor(textPrimaryColor)
                    .multilineTextAlignment(.center)
                    .lineSpacing(calculateLineHeight(fontSize) - fontSize)
                    .frame(maxWidth: 300)

                if let subtitleText = subtitleText, !subtitleText.isEmpty {
                    Text(subtitleText)
                        .font(.system(size: subtitleFontSize, weight: .semibold))
                        .foregroundColor(accentColor)
                        .multilineTextAlignment(.center)
                        .lineSpacing(calculateLineHeight(subtitleFontSize) - subtitleFontSize)
                }

                if let secondarySubitleText = secondarySubitleText, !secondarySubitleText.isEmpty {
                    Text(secondarySubitleText)
                        .font(.system(size: secondarySubtitleFontSize, weight: .semibold))
                        .foregroundColor(secondaryTextColor)
                        .multilineTextAlignment(.center)
                        .lineSpacing(
                            calculateLineHeight(secondarySubtitleFontSize)
                                - secondarySubtitleFontSize)
                }
            }
        }
    }
}
