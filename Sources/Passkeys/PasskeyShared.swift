import AuthenticationServices

public typealias Base64URLString = String

public enum Either<Create, Get>: Sendable where Create: Sendable, Get: Sendable {
    case create(Create), get(Get)
}

extension Array {
    var data: Data { withUnsafeBytes { .init($0) } }
}

extension Data {
    func toUIntArray() -> [UInt] {
        var UIntArray = [UInt](repeating: 0, count: self.count/MemoryLayout<UInt>.stride)
        _ = UIntArray.withUnsafeMutableBytes { self.copyBytes(to: $0) }
        return UIntArray
    }
    var uIntArray: [UInt] { toUIntArray() }
}

/**
 Specification reference: https://w3c.github.io/webauthn/#enum-transport
 */
@available(iOS 15.0, *)
public enum AuthenticatorTransport: String, Codable, Sendable {
    case ble
    case hybrid
    case nfc
    case usb

    func appleise() -> ASAuthorizationSecurityKeyPublicKeyCredentialDescriptor.Transport? {
        switch self {
        case .ble:
            return ASAuthorizationSecurityKeyPublicKeyCredentialDescriptor.Transport.bluetooth
        case .nfc:
            return ASAuthorizationSecurityKeyPublicKeyCredentialDescriptor.Transport.nfc
        case .usb:
            return ASAuthorizationSecurityKeyPublicKeyCredentialDescriptor.Transport.usb
        default:
            return nil
        }
    }
}

/**
 Specification reference: https://w3c.github.io/webauthn/#enum-attachment
 */
public enum AuthenticatorAttachment: String, Codable, Sendable {
    case platform

    // - cross-platform marks that the user wants to select a security key
    case crossPlatform = "cross-platform"
}

/**
 Specification reference: https://w3c.github.io/webauthn/#enum-attestation-convey
 */
@available(iOS 15.0, *)
public enum AttestationConveyancePreference: String, Decodable, Sendable {
    case direct
    case enterprise
    case indirect
    case none

    func appleise() -> ASAuthorizationPublicKeyCredentialAttestationKind {
        switch self {
        case .direct:
            return ASAuthorizationPublicKeyCredentialAttestationKind.direct
        case .indirect:
            return ASAuthorizationPublicKeyCredentialAttestationKind.indirect
        case .enterprise:
            return ASAuthorizationPublicKeyCredentialAttestationKind.enterprise
        default:
            return ASAuthorizationPublicKeyCredentialAttestationKind.direct
        }
    }
}

/**
 Specification reference: https://w3c.github.io/webauthn/#enum-credentialType
 */
public enum PublicKeyCredentialType: String, Codable, Sendable {
    case publicKey = "public-key"
}

/**
 Specification reference: https://w3c.github.io/webauthn/#enum-userVerificationRequirement
 */
@available(iOS 15.0, *)
public enum UserVerificationRequirement: String, Codable, Sendable {
    case discouraged
    case preferred
    case required

    func appleise () -> ASAuthorizationPublicKeyCredentialUserVerificationPreference {
        switch self {
        case .discouraged:
            return ASAuthorizationPublicKeyCredentialUserVerificationPreference.discouraged
        case .preferred:
            return ASAuthorizationPublicKeyCredentialUserVerificationPreference.preferred
        case .required:
            return ASAuthorizationPublicKeyCredentialUserVerificationPreference.required
        }
    }
}

/**
 Specification reference: https://w3c.github.io/webauthn/#enum-residentKeyRequirement
 */
@available(iOS 15.0, *)
public enum ResidentKeyRequirement: String, Decodable, Sendable {
    case discouraged
    case preferred
    case required

    func appleise() -> ASAuthorizationPublicKeyCredentialResidentKeyPreference {
        switch self {
        case .discouraged:
            return ASAuthorizationPublicKeyCredentialResidentKeyPreference.discouraged
        case .preferred:
            return ASAuthorizationPublicKeyCredentialResidentKeyPreference.preferred
        case .required:
            return ASAuthorizationPublicKeyCredentialResidentKeyPreference.required
        }
    }
}

/**
 Specification reference: https://w3c.github.io/webauthn/#enumdef-largeblobsupport
 */
public enum LargeBlobSupport: String, Sendable {
    case preferred
    case required

    @available(iOS 17.0, *)
    func appleise() -> ASAuthorizationPublicKeyCredentialLargeBlobRegistrationInput? {
        switch self {
        case .preferred:
            return ASAuthorizationPublicKeyCredentialLargeBlobRegistrationInput.supportPreferred
        case .required:
            return ASAuthorizationPublicKeyCredentialLargeBlobRegistrationInput.supportRequired
        }
    }
}

// - Structs

/**
 Specification reference: https://w3c.github.io/webauthn/#dictionary-authenticatorSelection
 */
@available(iOS 15.0, *)
public struct AuthenticatorSelectionCriteria: Decodable, Sendable {
    var authenticatorAttachment: AuthenticatorAttachment?

    var residentKey: ResidentKeyRequirement?

    var requireResidentKey: Bool? = false

    var userVerification: UserVerificationRequirement? = UserVerificationRequirement.preferred

    enum CodingKeys: String, CodingKey {
        case authenticatorAttachment
        case residentKey
        case requireResidentKey
        case userVerification
    }

    // We have to manually decode this
    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)

        let authenticatorAttachmentValue = try values.decodeIfPresent(String.self, forKey: .authenticatorAttachment)
        if let authenticatorAttachmentString = authenticatorAttachmentValue {
            authenticatorAttachment = AuthenticatorAttachment(rawValue: authenticatorAttachmentString)
        }

        let residentKeyValue = try values.decodeIfPresent(String.self, forKey: .residentKey)
        if let residentKeyString = residentKeyValue {
            residentKey = ResidentKeyRequirement(rawValue: residentKeyString)
        }

        requireResidentKey = try values .decodeIfPresent(Bool.self, forKey: .requireResidentKey)

        let userVerificationValue = try values.decodeIfPresent(String.self, forKey: .userVerification)
        if let userVerificationString = userVerificationValue {
            userVerification = UserVerificationRequirement(rawValue: userVerificationString)
        }
    }

    public init(authenticatorAttachment: AuthenticatorAttachment? = nil,
                requireResidentKey: Bool? = false,
                residentKey: ResidentKeyRequirement? = nil,
                userVerification: UserVerificationRequirement? = UserVerificationRequirement.preferred) {
        self.authenticatorAttachment = authenticatorAttachment
        self.requireResidentKey = requireResidentKey
        self.residentKey = residentKey
        self.userVerification = userVerification
    }
}

/**
 Specification reference: https://w3c.github.io/webauthn/#dictionary-pkcredentialentity
 */
internal struct PublicKeyCredentialEntity: Decodable {
    var name: String
}

/**
 Specification reference: https://w3c.github.io/webauthn/#dictionary-credential-params
 */
@available(iOS 15.0, *)
public struct PublicKeyCredentialParameters: Decodable, Sendable {
    var alg: ASCOSEAlgorithmIdentifier = .ES256

    var type: PublicKeyCredentialType = .publicKey

    func appleise() -> ASAuthorizationPublicKeyCredentialParameters {
        return .init(algorithm: ASCOSEAlgorithmIdentifier(self.alg.rawValue))
    }

    enum CodingKeys: String, CodingKey {
        case alg
        case type
    }

    // We have to manually decode this
    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)

        let algValue = try values.decodeIfPresent(Int.self, forKey: .alg)
        if let algInt = algValue {
            alg = ASCOSEAlgorithmIdentifier(algInt)
        }

        let typeValue = try values.decodeIfPresent(String.self, forKey: .type)
        if let typeString = typeValue {
            type = PublicKeyCredentialType(rawValue: typeString) ?? .publicKey
        }
    }

    public init(type: String, alg: Int) {
        self.type = PublicKeyCredentialType(rawValue: type) ?? .publicKey
        self.alg = ASCOSEAlgorithmIdentifier(alg)
    }
}

/**
 Specification reference: https://w3c.github.io/webauthn/#dictionary-rp-credential-params
 */
public struct PublicKeyCredentialRpEntity: Decodable, Sendable {

    var name: String

    var id: String?

    public init(name: String) {
        self.init(name: name, id: name)
    }

    public init(name: String, id: String? = nil) {
        self.name = name
        self.id = id
    }
}

/**
 Specification reference: https://w3c.github.io/webauthn/#dictdef-publickeycredentialuserentity
 */
public struct PublicKeyCredentialUserEntity: Decodable, Sendable {

    var name: String

    var displayName: String

    var id: String

    public init(name: String) {
        self.init(name: name, displayName: name, id: name)
    }

    public init(name: String, displayName: String, id: String) {
        self.name = name
        self.displayName = displayName
        self.id = id
    }
}

/**
 Specification reference: https://w3c.github.io/webauthn/#dictdef-publickeycredentialdescriptor
 */
@available(iOS 15.0, *)
public struct PublicKeyCredentialDescriptor: Decodable, Sendable {

    public enum Error: Swift.Error {
        case decodingErrorMissingID
    }

    var id: Base64URLString

    var transports: [AuthenticatorTransport]

    var type: PublicKeyCredentialType = .publicKey

    func getPlatformDescriptor() -> ASAuthorizationPlatformPublicKeyCredentialDescriptor? {
        guard let credentialIdData = Data(base64URLEncoded: self.id) else { return nil }
        return ASAuthorizationPlatformPublicKeyCredentialDescriptor.init(credentialID: credentialIdData)
    }

    func getCrossPlatformDescriptor() -> ASAuthorizationSecurityKeyPublicKeyCredentialDescriptor? {
        var transportsToUse = ASAuthorizationSecurityKeyPublicKeyCredentialDescriptor.Transport.allSupported

        if !transports.isEmpty {
            transportsToUse = transports.compactMap { $0.appleise() }
        }

        guard let credentialIdData = Data(base64URLEncoded: self.id) else { return nil }
        return .init(credentialID: credentialIdData, transports: transportsToUse)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case transports
        case type
    }

    // We have to manually decode this
    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)

        guard let decodedId = try values.decodeIfPresent(String.self, forKey: .id) else {
            throw Error.decodingErrorMissingID
        }
        id = decodedId

        transports = try values.decodeIfPresent([AuthenticatorTransport].self, forKey: .transports) ?? []

        let typeValue = try values.decodeIfPresent(String.self, forKey: .type)
        if let typeString = typeValue {
            type = PublicKeyCredentialType(rawValue: typeString) ?? .publicKey
        }
    }

    public init(id: String, transports: [AuthenticatorTransport]? = nil, type: PublicKeyCredentialType) {
        self.id = id
        self.transports = transports ?? []
        self.type = type
    }
}

/**
 Specification reference: https://w3c.github.io/webauthn/#dictdef-authenticationextensionslargeblobinputs
 */
public struct AuthenticationExtensionsLargeBlobInputs: Decodable, Sendable {
    // - Only valid during registration.
    var support: LargeBlobSupport?

    // - A boolean that indicates that the Relying Party would like to fetch the previously-written blob associated with the asserted credential. Only valid during authentication.
    var read: Bool?

    // - An opaque byte string that the Relying Party wishes to store with the existing credential. Only valid during authentication.
    // - We impose that the data is passed as base64-url encoding to make better align the passing of data from RN to native code
    var write: Data?

    enum CodingKeys: String, CodingKey {
        case support
        case read
        case write
    }

    // We have to manually decode this
    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)

        let supportValue = try values.decodeIfPresent(String.self, forKey: .support)
        if let supportString = supportValue {
            support = LargeBlobSupport(rawValue: supportString)
        }

        read = try values.decodeIfPresent(Bool.self, forKey: .read)

        // RN converts UInt8Array to Dictionary, need to decode it
        let writeDict = try values.decodeIfPresent([String: Int].self, forKey: .write)
        // sort dict, convert to array and then data
        write = writeDict?.sorted(by: { $0.key < $1.key }).map({ $0.value }).data
    }

    public init(support: LargeBlobSupport? = nil,
                read: Bool? = nil,
                write: Data? = nil) {
        self.support = support
        self.read = read
        self.write = write
    }
}

/**
 Specification reference: https://w3c.github.io/webauthn/#dictdef-authenticationextensionsclientinputs
 */
public struct AuthenticationExtensionsClientInputs: Decodable, Sendable {
    var largeBlob: AuthenticationExtensionsLargeBlobInputs?

    public init(largeBlob: AuthenticationExtensionsLargeBlobInputs? = nil) {
        self.largeBlob = largeBlob
    }
}

// ! There is only one webauthn extension currently supported on iOS as of iOS 17.0:
// - largeBlob extension: https://w3c.github.io/webauthn/#sctn-large-blob-extension

internal struct AuthenticationExtensionsClientOutputs {

    /**
     Specification reference: https://w3c.github.io/webauthn/#dictdef-authenticationextensionslargebloboutputs
     */
    internal struct AuthenticationExtensionsLargeBlobOutputs {
        // - true if, and only if, the created credential supports storing large blobs. Only present in registration outputs.
        let supported: Bool?

        // - The opaque byte string that was associated with the credential identified by rawId. Only valid if read was true.
        let blob: Data?

        // - A boolean that indicates that the contents of write were successfully stored on the authenticator, associated with the specified credential.
        let  written: Bool?
    }

    let largeBlob: AuthenticationExtensionsLargeBlobOutputs?
}
