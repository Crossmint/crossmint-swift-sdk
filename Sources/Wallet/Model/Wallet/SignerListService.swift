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
            let signers = await states(for: model.config.signers ?? [])
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
    private func states(for configs: [WalletSignerConfigApiModel]) async -> [WalletSigner] {
        await withTaskGroup(of: (Int, WalletSigner?).self) { group in
            for (index, config) in configs.enumerated() {
                let locator = config.locator
                let name = config.name
                group.addTask {
                    do {
                        guard let response = try await self.smartWalletService.getSigner(
                            locator.value,
                            chainType: self.chainType
                        ) else {
                            return (index, WalletSigner(locator: locator, status: .unknown, name: name))
                        }
                        guard let status = response.registrationStatus(
                            chainType: self.chainType,
                            chainName: self.chainName
                        ) else {
                            return (index, nil)
                        }
                        return (index, WalletSigner(locator: locator, status: status, name: name))
                    } catch {
                        Logger.smartWallet.warning(LogEvents.walletSignersStateLookupFailed, attributes: [
                            "locator": locator.value,
                            "error": "\(error)"
                        ])
                        return (index, WalletSigner(locator: locator, status: .unknown, name: name))
                    }
                }
            }
            var results = [WalletSigner?](repeating: nil, count: configs.count)
            for await (index, signer) in group {
                results[index] = signer
            }
            return results.compactMap { $0 }
        }
    }
}
