import Foundation
import SwiftUI
import Utils

struct EmbeddedCheckoutLabel: View {
    let text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .foregroundColor(Color(hex: "#00150D"))
            .font(.custom("Inter", size: 14).weight(.medium))
    }
}

#Preview {
    EmbeddedCheckoutLabel("Hello, world!")
}
