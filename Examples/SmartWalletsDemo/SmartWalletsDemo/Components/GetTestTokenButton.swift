import SwiftUI
import CrossmintCommonTypes

struct GetTestTokenButton: View {
    let currency: CryptoCurrency
    let action: () async -> Void
    @State private var isLoading = false

    var body: some View {
        Button(action: {
            isLoading = true
            Task {
                await action()
                await MainActor.run {
                    isLoading = false
                }
            }
        }) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: accentColor))
                } else {
                    icon
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                        .foregroundColor(accentColor)
                }

                Text("Get test \(currencyText)")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(accentColor)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Color.white)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(accentColor.opacity(0.3), lineWidth: 1)
            )
        }
        .disabled(isLoading)
    }

    private var accentColor: Color {
        Color.green
    }

    private var icon: Image {
        switch currency {
        case .usdc:
            return Image(systemName: "dollarsign.circle.fill")
        default:
            return Image(systemName: "creditcard.circle.fill")
        }
    }

    private var currencyText: String {
        currency.name.uppercased()
    }
}

#Preview {
    VStack(spacing: 16) {
        GetTestTokenButton(currency: .sol) {}
        GetTestTokenButton(currency: .usdc) {}
    }
    .padding()
    .background(Color(UIColor.secondarySystemBackground))
}
