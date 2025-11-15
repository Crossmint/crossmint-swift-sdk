import Foundation

/**
 Specification reference: https://w3c.github.io/webauthn/#typedefdef-publickeycredentialjson
 */
@available(iOS 15.0, *)
public typealias PublicKeyCredentialJSON = Either<RegistrationResponseJSON, AuthenticationResponseJSON>

/**
 Specification reference: https://w3c.github.io/webauthn/#dictdef-registrationresponsejson
 */
@available(iOS 15.0, *)
public struct RegistrationResponseJSON: Sendable {

    public var id: Data

    public var rawId: Data

    public var response: AuthenticatorAttestationResponseJSON

    public var authenticatorAttachment: AuthenticatorAttachment?

    public var clientExtensionResults: AuthenticationExtensionsClientOutputsJSON?

    public var type: PublicKeyCredentialType = .publicKey

}

/**
 Specification reference: https://w3c.github.io/webauthn/#dictdef-authenticatorattestationresponsejson
 */
@available(iOS 15.0, *)
public struct AuthenticatorAttestationResponseJSON: Sendable {

    public var clientDataJSON: Data

    public var authenticatorData: Data?

    public var transports: [AuthenticatorTransport]?

    public var publicKeyAlgorithm: Int?

    public var publicKey: ParsedPublicKeyP256?

    public var attestationObject: Data

}

/**
 Specification reference: https://w3c.github.io/webauthn/#dictdef-authenticationresponsejson
 */
public struct AuthenticationResponseJSON: Codable, Sendable {

    public let type: PublicKeyCredentialType = .publicKey

    public let id: Data

    public let rawId: Data?

    let authenticatorAttachment: AuthenticatorAttachment?

    public let response: AuthenticatorAssertionResponseJSON

    public let clientExtensionResults: AuthenticationExtensionsClientOutputsJSON?

}

/**
 Specification reference: https://w3c.github.io/webauthn/#dictdef-authenticatorassertionresponsejson
 */
public struct AuthenticatorAssertionResponseJSON: Codable, Sendable {

    public let authenticatorData: Data

    public let clientDataJSON: Data

    public let signature: Data

    public let userHandle: Base64URLString?

    let attestationObject: Base64URLString?

}

/**
 Specification reference: https://w3c.github.io/webauthn/#dictdef-authenticationextensionsclientoutputsjson
 */
public struct  AuthenticationExtensionsClientOutputsJSON: Codable, Sendable {
    var largeBlob: AuthenticationExtensionsLargeBlobOutputsJSON?
}

/**
 We convert this to `AuthenticationExtensionsLargeBlobOutputsJSON` instead of `AuthenticationExtensionsLargeBlobOutputs` for consistency
 and because it is what is actually returned to RN
 
 Specification reference: https://w3c.github.io/webauthn/#dictdef-authenticationextensionslargebloboutputs
 */
public struct AuthenticationExtensionsLargeBlobOutputsJSON: Codable, Sendable {
    var supported: Bool?

    var blob: [UInt]?

    var written: Bool?
}
