import SwiftUI

struct EmbeddedCheckoutLineItemsSectionTemplateView<Content: View>: View {
    let title: String
    let content: Content

    public init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack {
            EmbeddedCheckoutInvoiceTitleView(title)
            content
        }
    }
}
