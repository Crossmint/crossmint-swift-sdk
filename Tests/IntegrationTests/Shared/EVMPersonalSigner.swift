import CrossmintCommonTypes
import Foundation
import SwiftKeccak
@testable import Wallet

/// An EVM external wallet that approves the way a wallet app does: EIP-191 `personal_sign` over the raw
/// message bytes, which is what the API verifies. `EVMKeyPairSigner.sign` signs the bare digest instead.
final class EVMPersonalSigner: Signer, @unchecked Sendable {
    typealias AdminType = ExternalWalletSignerData

    let signerType: SignerType = .externalWallet
    let keypair: EVMKeyPairSigner
    let address: String

    static func make() async throws -> EVMPersonalSigner {
        let keypair = try EVMKeyPairSigner()
        try await keypair.initialize(nil)
        return EVMPersonalSigner(keypair: keypair, address: await keypair.evmAddress.address)
    }

    private init(keypair: EVMKeyPairSigner, address: String) {
        self.keypair = keypair
        self.address = address
    }

    var adminSigner: ExternalWalletSignerData { ExternalWalletSignerData(address: address) }
    var config: SignerConfig { .externalWallet(address) { [self] message in try await self.sign(message: message) } }

    func initialize(_ service: SmartWalletService?) async throws(SignerError) {}

    func sign(message: String) async throws(SignerError) -> String {
        guard let bytes = Self.data(hex: message) else { throw .invalidMessage }
        return try await keypair.sign(message: Self.personalSignDigest(of: bytes))
    }

    func signText(_ text: String) async throws(SignerError) -> String {
        try await keypair.sign(message: Self.personalSignDigest(of: Data(text.utf8)))
    }

    func approvals(withSignature signature: String) async throws(SignerError) -> [SignRequestApi.Approval] {
        [.keypair(signer: adminSigner.locator, signature: signature)]
    }

    private static func personalSignDigest(of bytes: Data) -> String {
        let prefixed = Data("\u{19}Ethereum Signed Message:\n\(bytes.count)".utf8) + bytes
        return "0x" + keccak256(prefixed).map { String(format: "%02x", $0) }.joined()
    }

    private static func data(hex: String) -> Data? {
        let digits = hex.hasPrefix("0x") ? String(hex.dropFirst(2)) : hex
        guard digits.count % 2 == 0 else { return nil }
        var data = Data(capacity: digits.count / 2)
        var index = digits.startIndex
        while index < digits.endIndex {
            let next = digits.index(index, offsetBy: 2)
            guard let byte = UInt8(digits[index..<next], radix: 16) else { return nil }
            data.append(byte)
            index = next
        }
        return data
    }
}
