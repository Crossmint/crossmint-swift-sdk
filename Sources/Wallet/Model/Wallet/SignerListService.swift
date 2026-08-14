import CrossmintCommonTypes
import Foundation
import Logger

final class SignerListService: Sendable {
    private let smartWalletService: SmartWalletService
    private let chainType: ChainType
    private let chainName: String

    init(smartWalletService: SmartWalletService, chainType: ChainType, chainName: String) {
        self.smartWalletService = smartWalletService
        self.chainType = chainType
        self.chainName = chainName
    }

    func list() async throws(WalletError) -> [WalletSigner] {
        Logger.smartWallet.info(LogEvents.walletSignersStart)
        do {
            let model = try await smartWalletService.getWallet(GetMeWalletRequest(chainType: chainType))
            let locators = (model.config.signers ?? []).map(\.locator)
            let signers = await states(for: locators)
            Logger.smartWallet.info(LogEvents.walletSignersSuccess, attributes: [
                "count": "\(signers.count)"
            ])
            return signers
        } catch {
            Logger.smartWallet.error(LogEvents.walletSignersError, attributes: [
                "error": "\(error)"
            ])
            throw error
        }
    }

    /// Fetches each signer's state concurrently, so one broken signer doesn't fail the
    /// whole list: a failed lookup yields ``SignerStatus/unknown``. On EVM, signers without
    /// a registration entry for the wallet's chain are omitted. Preserves the config order.
    private func states(for locators: [String]) async -> [WalletSigner] {
        await withTaskGroup(of: (Int, WalletSigner?).self) { group in
            for (index, locator) in locators.enumerated() {
                group.addTask {
                    do {
                        guard let response = try await self.smartWalletService.getSigner(
                            locator,
                            chainType: self.chainType
                        ) else {
                            return (index, WalletSigner(locator: locator, status: .unknown))
                        }
                        guard let status = response.registrationStatus(
                            chainType: self.chainType,
                            chainName: self.chainName
                        ) else {
                            return (index, nil)
                        }
                        return (index, WalletSigner(locator: locator, status: status))
                    } catch {
                        Logger.smartWallet.warning(LogEvents.walletSignersStateLookupFailed, attributes: [
                            "locator": locator,
                            "error": "\(error)"
                        ])
                        return (index, WalletSigner(locator: locator, status: .unknown))
                    }
                }
            }
            var results = [WalletSigner?](repeating: nil, count: locators.count)
            for await (index, signer) in group {
                results[index] = signer
            }
            return results.compactMap { $0 }
        }
    }
}
