import CrossmintCommonTypes
import Foundation
import P256K
import libsecp256k1
import Security
import SwiftKeccak

public typealias Secp256k1PrivateKey = P256K.Signing.PrivateKey
public typealias Secp256k1PublicKey = P256K.Signing.PublicKey

// swiftlint:disable:next large_tuple
private typealias Signature = (r: [UInt8], s: [UInt8], v: UInt)

extension Secp256k1PrivateKey: @unchecked @retroactive Sendable {}
extension Secp256k1PublicKey: @unchecked @retroactive Sendable {}

actor EVMKeyPairSignerState {
    var adminSigner: ExternalWalletSignerData!
    var secp256k1PrivateKey: Secp256k1PrivateKey!
    var secp256k1PublicKey: Secp256k1PublicKey!
    var evmAddress: EVMAddress!
    var privateKeyString: String!
    var publicKeyString: String!

    init() {}

    var isInitialized: Bool {
        secp256k1PrivateKey != nil
    }

    func initialize(
        privateKeyData: [UInt8]?,
        signerType: SignerType
    ) throws(SignerError) {
        // Check if already initialized
        if secp256k1PrivateKey != nil {
            return
        }

        // Initialize Secp256k1 private key
        let secp256k1PrivateKey: Secp256k1PrivateKey
        do {
            if let privateKeyData = privateKeyData {
                secp256k1PrivateKey = try Secp256k1PrivateKey(dataRepresentation: privateKeyData, format: .uncompressed)
            } else {
                secp256k1PrivateKey = try Secp256k1PrivateKey(format: .uncompressed)
            }
        } catch {
            throw SignerError.invalidPrivateKey
        }

        // Initialize Secp256k1 public key
        let secp256k1PublicKey = secp256k1PrivateKey.publicKey

        // Initialize private key string
        let privateKeyString = secp256k1PrivateKey.dataRepresentation.toHexString(withPrefix: false)

        // Initialize public key string
        let publicKeyData = secp256k1PublicKey.dataRepresentation.dropFirst()
        let publicKeyString = publicKeyData.toHexString(withPrefix: true)

        // Initialize EVM address
        let addressPrefixed = keccak256(publicKeyData).suffix(20).toHexString(withPrefix: true)
        guard let ethereumAddress = try? EVMAddress(address: addressPrefixed) else {
            throw SignerError.invalidAddress
        }

        // Update state
        self.secp256k1PrivateKey = secp256k1PrivateKey
        self.secp256k1PublicKey = secp256k1PublicKey
        self.privateKeyString = privateKeyString
        self.publicKeyString = publicKeyString
        self.evmAddress = ethereumAddress
        self.adminSigner = ExternalWalletSignerData(address: ethereumAddress.address)
    }

    func getPrivateKey() -> Secp256k1PrivateKey {
        guard let privateKey = secp256k1PrivateKey else {
            fatalError("Trying to use uninitialized private key")
        }
        return privateKey
    }
}

public final class EVMKeyPairSigner: Signer {
    public typealias AdminType = ExternalWalletSignerData

    public nonisolated let signerType: SignerType = .externalWallet

    private let state = EVMKeyPairSignerState()
    private let privateKeyData: [UInt8]?

    public var adminSigner: ExternalWalletSignerData {
        get async {
            await state.adminSigner
        }
    }

    public var evmAddress: EVMAddress {
        get async {
            await state.evmAddress
        }
    }

    public var privateKey: String {
        get async {
            await state.privateKeyString
        }
    }

    public var publicKey: String {
        get async {
            await state.publicKeyString
        }
    }

    public init(privateKey: String) throws(SignerError) {
        guard let privateKeyData = try? privateKey.bytes else {
            throw .invalidPrivateKey
        }
        self.privateKeyData = privateKeyData
    }

    public init(privateKeyData: [UInt8]? = nil) throws(SignerError) {
        if privateKeyData?.isEmpty == true {
            throw .invalidPrivateKey
        }
        self.privateKeyData = privateKeyData
    }

    public func initialize(_ service: SmartWalletService?) async throws(SignerError) {
        if await state.isInitialized {
            return
        }

        try await state.initialize(privateKeyData: privateKeyData, signerType: signerType)
    }

    public func sign(
        message: String
    ) async throws(SignerError) -> String {
        guard let messageData = message.hexData else {
            throw .invalidMessage
        }
        return try await signHash(digest: messageData.bytes)
    }

    public func approvals(
        withSignature signature: String
    ) async throws(SignerError) -> [SignRequestApi.Approval] {
        [
            .keypair(signer: await adminSigner.locator, signature: signature)
        ]
    }

    private func signHash(
        digest: [UInt8]
    ) async throws(SignerError) -> String {
        let signature = try await rawSign(digest: digest)

        // swiftlint:disable:next identifier_name
        let v: UInt
        // Ethereum uses recovery id 27 and 28, not 0 and 1
        if signature.v < 27 {
            v = signature.v + 27
        } else {
            v = signature.v
        }

        let vHex = String(v, radix: 16, uppercase: false)

        let rPart = "\(Data(signature.r).toHexString(withPrefix: false))"
        let sPart = "\(Data(signature.s).toHexString(withPrefix: false))"

        return "\(rPart)\(sPart)\(vHex)".withHexPrefix
    }

    private func rawSign(digest: [UInt8]) async throws(SignerError) -> Signature {
        let privateKey = await state.getPrivateKey()

        var hash = digest

        let ecdsaMemory = MemoryLayout<secp256k1_ecdsa_recoverable_signature>.size

        let ecdsaMemoryStorage = malloc(ecdsaMemory)

        guard let signaturePointer = ecdsaMemoryStorage?.assumingMemoryBound(
            to: secp256k1_ecdsa_recoverable_signature.self
        ) else {
            throw .signingFailed
        }

        guard let context = secp256k1_context_create(
            UInt32(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY)
        ) else {
            throw .signingFailed
        }

        defer {
            secp256k1_context_destroy(context)
            free(signaturePointer)
        }

        let keyBytes = (privateKey.dataRepresentation as NSData).bytes.assumingMemoryBound(to: UInt8.self)
        guard secp256k1_ecdsa_sign_recoverable(context, signaturePointer, &hash, keyBytes, nil, nil) == 1 else {
            throw .signingFailed
        }

        var signature = [UInt8](repeating: 0, count: 65)
        var recid: Int32 = 0

        secp256k1_ecdsa_recoverable_signature_serialize_compact(context, &signature, &recid, signaturePointer)

        return Signature(r: Array(signature[0..<32]), s: Array(signature[32..<64]), v: UInt(recid))
    }
}
