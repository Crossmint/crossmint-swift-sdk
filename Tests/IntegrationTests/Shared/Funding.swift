import CrossmintCommonTypes
import Foundation
@testable import Wallet

enum Funding {
    /// The faucet returns before the credit lands on chain; wait for the balance the test needs.
    static func fund(_ wallet: Wallet, usdxm amount: Int, timeout: TimeInterval = 90) async throws {
        try await wallet.fund(token: .usdxm, amount: amount)
        _ = try await Eventually.value(timeout: timeout, describing: "\(wallet.address) reaching \(amount) USDXM") {
            try await usdxmBalance(of: wallet) >= Double(amount) ? true : nil
        }
    }

    static func usdxmBalance(of wallet: Wallet) async throws -> Double {
        let balances = try await wallet.balances([.usdxm])
        let entry = balances.tokens.first { $0.name.lowercased() == "usdxm" }
        return Double(entry?.amount ?? "0") ?? 0
    }
}
