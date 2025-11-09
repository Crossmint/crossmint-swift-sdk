import SwiftUI

struct SecondaryButton: View {
    let text: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(text)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)

                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
        }
    }
}
