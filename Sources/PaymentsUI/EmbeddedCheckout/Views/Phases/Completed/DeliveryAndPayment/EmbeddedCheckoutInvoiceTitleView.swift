import SwiftUI
import Utils

struct EmbeddedCheckoutInvoiceTitleView: View {
    let title: String

    // Constants for appearance - these would ideally come from an AppearanceManager
    private let baseFontSize: CGFloat = 4.5
    private let fontWeight: Font.Weight = .semibold
    private let textColor = Color(hex: "#00150D")  // Assuming this is the equivalent of textPrimary

    public init(_ title: String) {
        self.title = title
    }

    private func calculateLineHeight(_ fontSize: CGFloat) -> CGFloat {
        return fontSize * 1.3  // Approximate line height calculation similar to the React component
    }

    var body: some View {
        Text(title)
            .font(.system(size: baseFontSize * 4))  // Similar to multiplying by 4.5 in the React component
            .fontWeight(fontWeight)  // Equivalent to fontWeight: 600
            .foregroundColor(textColor)
            .lineSpacing(calculateLineHeight(baseFontSize * 4) - baseFontSize * 4)  // Adjust line height
            .frame(maxWidth: .infinity, alignment: .leading)  // Equivalent to self-start
    }
}

#Preview {
    VStack(alignment: .leading) {
        EmbeddedCheckoutInvoiceTitleView("Your Invoice")
    }
    .padding()
}
