//
//  Wallet+PendingDeviceKey.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 29/10/26.
//

import CrossmintCommonTypes
import DeviceSigner
import Logger

enum PendingDeviceRegistration {
    case awaitingApproval(Transaction)
    case activated
    case none
}

extension Wallet {
    func pendingDeviceRegistration(
        storage: any DeviceSignerKeyStorage
    ) async throws(WalletError) -> PendingDeviceRegistration {
        await restorePendingDeviceKey(storage: storage)
        guard let pendingDeviceKey else { return .none }
        let transaction: Transaction
        do {
            transaction = try await smartWalletService.transaction(
                withId: pendingDeviceKey.transactionId,
                chainType: chain.chainType
            )
        } catch {
            throw .walletGeneric("Could not read the device signer transaction: \(error.message)")
        }
        switch transaction.status {
        case .success:
            guard await activatePendingDeviceKey() else {
                throw .walletGeneric("Could not save the approved device key. Call recover() again.")
            }
            return .activated
        case .failed:
            try? await pendingDeviceKey.storage.deletePendingKey(publicKeyBase64: pendingDeviceKey.publicKeyBase64)
            self.pendingDeviceKey = nil
            return .none
        case .pending, .awaitingApproval:
            return .awaitingApproval(transaction)
        }
    }

    func activatePendingDeviceKey() async -> Bool {
        guard let pending = pendingDeviceKey else { return false }
        do {
            try await deviceSignerService.persistKey(pending.publicKeyBase64, in: pending.storage)
        } catch {
            Logger.smartWallet.error(LogEvents.walletRecoverError, attributes: ["error": "\(error)"])
            return false
        }
        pendingDeviceKey = nil
        deviceKeyIsUsable()
        if let replacedSigner = pending.replacedSigner {
            await removeStaleDeviceSigner(replacedSigner)
        }
        return true
    }

    func restorePendingDeviceKey(storage: any DeviceSignerKeyStorage) async {
        guard pendingDeviceKey == nil, chain.chainType != .evm else { return }
        guard let model = try? await smartWalletService.getWallet(GetMeWalletRequest(chainType: chain.chainType))
        else { return }
        let deviceKeys = (model.config.signers ?? []).compactMap { entry -> String? in
            guard case .device(let publicKey) = entry.locator else { return nil }
            return publicKey
        }
        guard let heldKey = deviceKeys.first(where: { storage.hasKey(publicKeyBase64: $0) }),
              let registration = try? await smartWalletService.getSigner(
                SignerLocator.device(publicKey: heldKey).value,
                chainType: chain.chainType
              ),
              let transaction = registration.transaction
        else { return }
        let otherKeys = deviceKeys.filter { $0 != heldKey }
        pendingDeviceKey = PendingDeviceKey(
            transactionId: transaction.id,
            publicKeyBase64: heldKey,
            storage: storage,
            replacedSigner: otherKeys.count == 1 ? .device(publicKey: otherKeys[0]) : nil
        )
        Logger.smartWallet.info(LogEvents.walletRecoverPendingKeyRestored, attributes: [
            "transactionId": transaction.id
        ])
    }
}
