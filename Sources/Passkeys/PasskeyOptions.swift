import AuthenticationServices

/**
 navigator.credentials.create request options
 
 Specification reference: https://w3c.github.io/webauthn/#dictionary-makecredentialoptions
 */
@available(iOS 15.0, *)
public struct PasskeyCredentialCreationOptions: Decodable {

    var rp: PublicKeyCredentialRpEntity

    var user: PublicKeyCredentialUserEntity

    var challenge: Base64URLString

    var pubKeyCredParams: [PublicKeyCredentialParameters]

    var timeout: Int?

    var excludeCredentials: [PublicKeyCredentialDescriptor]?

    var authenticatorSelection: AuthenticatorSelectionCriteria?

    var attestation: AttestationConveyancePreference?

    var extensions: AuthenticationExtensionsClientInputs?

    public init(
        rp: PublicKeyCredentialRpEntity,
        user: PublicKeyCredentialUserEntity,
        challenge: Base64URLString,
        pubKeyCredParams: [PublicKeyCredentialParameters],
        timeout: Int? = nil,
        excludeCredentials: [PublicKeyCredentialDescriptor]? = nil,
        authenticatorSelection: AuthenticatorSelectionCriteria? = nil,
        attestation: AttestationConveyancePreference? = nil,
        extensions: AuthenticationExtensionsClientInputs? = nil
    ) {
        self.rp = rp
        self.user = user
        self.challenge = challenge
        self.pubKeyCredParams = pubKeyCredParams
        self.timeout = timeout
        self.excludeCredentials = excludeCredentials
        self.authenticatorSelection = authenticatorSelection
        self.attestation = attestation
        self.extensions = extensions
    }
}

extension PasskeyCredentialCreationOptions: Sendable {}

/**
 navigator.credentials.get request options
 
 Specification reference: https://w3c.github.io/webauthn/#dictionary-assertion-options
 */
@available(iOS 15.0, *)
public struct PasskeyCredentialRequestOptions: Decodable {

    var challenge: Data

    var rpId: String

    var timeout: Int?

    var allowCredentials: [PublicKeyCredentialDescriptor]?

    var userVerification: UserVerificationRequirement?

    var extensions: AuthenticationExtensionsClientInputs?

    public init(
        challenge: Data,
        rpId: String,
        timeout: Int? = 60000,
        allowCredentials: [PublicKeyCredentialDescriptor]? = nil,
        userVerification: UserVerificationRequirement? = nil,
        extensions: AuthenticationExtensionsClientInputs? = nil
    ) {
        self.challenge = challenge
        self.rpId = rpId
        self.timeout = timeout
        self.allowCredentials = allowCredentials
        self.userVerification = userVerification
        self.extensions = extensions
    }

}
