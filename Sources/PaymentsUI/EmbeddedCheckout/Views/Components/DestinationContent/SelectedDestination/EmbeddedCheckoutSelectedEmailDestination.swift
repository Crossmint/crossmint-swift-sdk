import SwiftUI
import Utils

struct EmbeddedCheckoutSelectedEmailDestination: View {
    let email: String?

    // TODO use logged in session data
    var title: String {
        return email ?? ""
    }

    var body: some View {
        EmbeddedCheckoutSelectedDestinationTemplate(
            icon: Image("emailIcon", bundle: .module),
            title: title, subTitle: "Crossmint wallet"
        )  // TODO add this logo to the assets
    }
}
