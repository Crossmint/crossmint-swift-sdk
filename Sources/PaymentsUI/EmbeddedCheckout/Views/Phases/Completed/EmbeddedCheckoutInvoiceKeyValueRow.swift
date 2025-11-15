import SwiftUI
import Utils

struct EmbeddedCheckoutInvoiceKeyValueRow: View {
    let label: String
    let value: String
    let link: String?
    let isBold: Bool
    @Environment(\.openURL) private var openURL

    // Constants for appearance - would ideally come from an AppearanceManager
    private let fontSize: CGFloat = 16  // Base size * 4
    private let textSecondaryColor = Color(hex: "#67797F")  // Approximate text secondary color
    private let textPrimaryColor = Color(hex: "#00150D")  // Approximate text primary color

    private func calculateLineHeight(_ fontSize: CGFloat) -> CGFloat {
        return fontSize * 1.3  // Approximate line height calculation
    }

    init(label: String, value: String, link: String?, isBold: Bool = false) {
        self.label = label
        self.value = value
        self.link = link
        self.isBold = isBold
    }

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: fontSize))
                .fontWeight(isBold ? .bold : .regular)
                .foregroundColor(textSecondaryColor)
                .lineSpacing(calculateLineHeight(fontSize) - fontSize)

            Spacer()

            Group {
                if link != nil {
                    Text(value)
                        .font(.system(size: fontSize))
                        .fontWeight(isBold ? .bold : .regular)
                        .foregroundColor(textSecondaryColor)
                        .lineSpacing(calculateLineHeight(fontSize) - fontSize)
                        .overlay(
                            Rectangle()
                                .frame(height: 1)
                                .offset(y: 1)
                                .foregroundColor(textSecondaryColor),
                            alignment: .bottom
                        )
                } else {
                    Text(value)
                        .font(.system(size: fontSize))
                        .fontWeight(isBold ? .bold : .regular)
                        .foregroundColor(textSecondaryColor)
                        .lineSpacing(calculateLineHeight(fontSize) - fontSize)
                }
            }
            .onTapGesture {
                if let link = link, let url = URL(string: link) {
                    openURL(url)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    VStack(spacing: 16) {
        EmbeddedCheckoutInvoiceKeyValueRow(label: "Transaction ID", value: "1234567890", link: nil)
        EmbeddedCheckoutInvoiceKeyValueRow(
            label: "Etherscan", value: "View on Etherscan", link: "https://etherscan.io")
        EmbeddedCheckoutInvoiceKeyValueRow(
            label: "Total", value: "$123.45", link: nil, isBold: true)
    }
    .padding()
}
