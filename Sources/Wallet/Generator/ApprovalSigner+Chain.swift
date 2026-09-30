import CrossmintCommonTypes
import Foundation
import Utils

extension ApprovalSigner {
    func approvals(
        for message: String,
        on chainType: ChainType
    ) async throws(SignerError) -> [SignRequestApi.Approval] {
        try await approvals(for: try challenge(for: message, on: chainType))
    }

    private func challenge(for message: String, on chainType: ChainType) throws(SignerError) -> String {
        guard (self as? any Signer)?.signerType == .passkey,
              chainType == .solana || chainType == .stellar else {
            return message
        }
        guard let bytes = Data(base64Encoded: message) else {
            throw .invalidMessage
        }
        return bytes.toHexString(withPrefix: true)
    }
}
