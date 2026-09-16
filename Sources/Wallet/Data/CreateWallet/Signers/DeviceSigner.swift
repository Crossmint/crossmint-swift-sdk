import DeviceSigner
import Foundation

struct DeviceSigner: ApprovalSigner {
    let storage: any DeviceSignerKeyStorage
    let address: String

    var locator: SignerLocator? {
        get async {
            guard let publicKeyBase64 = await storage.getKey(address: address),
                  DevicePublicKey(publicKeyBase64: publicKeyBase64) != nil else { return nil }
            return .device(publicKey: publicKeyBase64)
        }
    }

    func initialize(_ service: SmartWalletService?) async throws(SignerError) {}

    func approvals(for message: String) async throws(SignerError) -> [SignRequestApi.Approval] {
        guard let locator = await locator else { throw .device(.keyNotFound) }
        do {
            let (r, s) = try await storage.signMessage(address: address, message: message)
            return [.device(signer: locator.value, signature: .init(r: r, s: s))]
        } catch {
            throw .device(error)
        }
    }
}
