import SwiftUI

struct HeadingTitle: View {
    private let text: String

    public init(text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.custom("Inter", size: 20))  // TODO might need to add font to project
            .fontWeight(.medium)
            .dynamicTypeSize(.medium...(.accessibility3))
    }
}
