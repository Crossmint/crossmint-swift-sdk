import SwiftUI

struct EmbeddedCheckoutTermsOfServiceView: View {
    var body: some View {
        Text("By continuing, you accept Crossmint's terms.")
            .font(.custom("Inter", size: 14))
            .fontWeight(.regular)
            .foregroundColor(Color(hex: "#67797F"))
            .dynamicTypeSize(.medium...(.accessibility3))
    }
}
