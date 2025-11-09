import SwiftUI
import Wallet
import CrossmintCommonTypes

struct WalletBalanceEntryView: View {
    let icon: Image
    let currencyName: String
    let balance: String

    var body: some View {
        HStack {
            // Left side with icon and currency name
            HStack(spacing: 12) {
                Text(currencyName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
            }

            Spacer()

            // Right side with balance
            Text(balance)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(8)
    }
}

// Convenience initializer for CryptoCurrency
extension WalletBalanceEntryView {
    init(currency: CryptoCurrency, balance: ChainBalances) {
        let value = NSDecimalNumber(decimal: balance.total).doubleValue
        let formattedBalance = "\(String(format: "%.\(balance.decimals)f", value)) \(currency.name.uppercased())"
        self.icon = Image(systemName: "creditcard.circle.fill")
        self.currencyName = currency.name.capitalized

        self.balance = formattedBalance
    }
}

#Preview {
    VStack(spacing: 12) {
        WalletBalanceEntryView(
            icon: Image(systemName: "dollarsign.circle.fill"),
            currencyName: "USDC",
            balance: "$0.00"
        )
        WalletBalanceEntryView(
            icon: Image(systemName: "s.circle.fill"),
            currencyName: "Solana",
            balance: "0.00 SOL"
        )
    }
    .padding()
    .background(Color(UIColor.secondarySystemBackground))
}
