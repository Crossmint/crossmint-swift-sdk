import SwiftUI
import UIKit

struct CrossmintPoweredView: View {
    var height: CGFloat = 20
    var textColor: Color = Color.gray.opacity(0.7)
    var spacing: CGFloat = 4

    var body: some View {
        HStack(spacing: spacing) {
            Image("crossmint-icon-gray")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: height * 0.8)

            Text("Powered by crossmint")
                .font(.system(size: height * 0.7))
                .foregroundColor(textColor)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview
struct CrossmintPoweredView_Previews: PreviewProvider {
    static var previews: some View {
        CrossmintPoweredView()
    }
}
