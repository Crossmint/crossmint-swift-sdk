import CrossmintCommonTypes
import Foundation
@testable import Wallet

enum Funding {
    /// The faucet returns before the credit lands on chain; wait for the balance the test needs.
    static func fund(_ wallet: Wallet, usdxm amount: Int, timeout: TimeInterval = 90) async throws {
        try await wallet.fund(token: .usdxm, amount: amount)
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if try await usdxmBalance(of: wallet) >= Double(amount) { return }
            try await Task.sleep(nanoseconds: 3_000_000_000)
        }
        throw IntegrationSetupError(message: "\(wallet.address) did not reach \(amount) USDXM within \(Int(timeout)) s")
    }

    static func usdxmBalance(of wallet: Wallet) async throws -> Double {
        let balances = try await wallet.balances([.usdxm])
        let entry = balances.tokens.first { $0.name.lowercased() == "usdxm" }
        return Double(entry?.amount ?? "0") ?? 0
    }
}
