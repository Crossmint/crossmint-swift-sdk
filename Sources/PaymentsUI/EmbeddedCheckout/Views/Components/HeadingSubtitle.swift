import SwiftUI

struct HeadingSubtitle: View {
    private let text: String

    public init(text: String) {
        self.text = text
    }

    var body: some View {
        Text(text).font(.custom("Inter", size: 16))  // TODO might need to add font to project
            .fontWeight(.regular)
            .foregroundColor(Color(hex: "#67797F"))
            .dynamicTypeSize(.medium...(.accessibility3))
    }
}
