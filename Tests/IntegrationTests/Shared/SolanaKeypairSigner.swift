import CrossmintCommonTypes
import CryptoKit
import Foundation
@testable import Wallet

/// An ed25519 external wallet for Solana: the address is the base58 public key, and approvals sign the
/// base58 message the API hands back, as a wallet app would.
final class SolanaKeypairSigner: Signer, @unchecked Sendable {
    typealias AdminType = ExternalWalletSignerData

    let signerType: SignerType = .externalWallet
    private let privateKey = Curve25519.Signing.PrivateKey()

    var address: String { Base58.encode(privateKey.publicKey.rawRepresentation) }
    var adminSigner: ExternalWalletSignerData { ExternalWalletSignerData(address: address) }
    var config: SignerConfig { .externalWallet(address) { [self] message in try self.signBase58(message) } }

    func initialize(_ service: SmartWalletService?) async throws(SignerError) {}

    func sign(message: String) async throws(SignerError) -> String {
        do {
            return try signBase58(message)
        } catch {
            throw .signingFailed
        }
    }

    func approvals(withSignature signature: String) async throws(SignerError) -> [SignRequestApi.Approval] {
        [.keypair(signer: adminSigner.locator, signature: signature)]
    }

    private func signBase58(_ message: String) throws -> String {
        guard let bytes = Base58.decode(message) else { throw SignerError.invalidMessage }
        return Base58.encode(try privateKey.signature(for: bytes))
    }
}

enum Base58 {
    private static let alphabet = Array("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")
    private static let indexes: [Character: Int] = Dictionary(
        uniqueKeysWithValues: alphabet.enumerated().map { ($1, $0) }
    )

    static func encode(_ data: Data) -> String {
        let leadingZeros = data.prefix { $0 == 0 }.count
        var digits: [Int] = []
        for byte in data.dropFirst(leadingZeros) {
            var carry = Int(byte)
            for index in digits.indices {
                carry += digits[index] << 8
                digits[index] = carry % 58
                carry /= 58
            }
            while carry > 0 {
                digits.append(carry % 58)
                carry /= 58
            }
        }
        return String(repeating: "1", count: leadingZeros) + String(digits.reversed().map { alphabet[$0] })
    }

    static func decode(_ string: String) -> Data? {
        let leadingOnes = string.prefix { $0 == "1" }.count
        var bytes: [UInt8] = []
        for character in string.dropFirst(leadingOnes) {
            guard var carry = indexes[character] else { return nil }
            for index in bytes.indices {
                carry += Int(bytes[index]) * 58
                bytes[index] = UInt8(carry & 0xff)
                carry >>= 8
            }
            while carry > 0 {
                bytes.append(UInt8(carry & 0xff))
                carry >>= 8
            }
        }
        return Data(repeating: 0, count: leadingOnes) + Data(bytes.reversed())
    }
}
