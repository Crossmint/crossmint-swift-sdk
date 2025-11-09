import Foundation
import AuthenticationServices

@available(iOS 15.0, *)
class PasskeyDelegate: NSObject, ASAuthorizationControllerDelegate,
                        ASAuthorizationControllerPresentationContextProviding {
    private var continuation: CheckedContinuation<PublicKeyCredentialJSON, Error>?

    // Initializes delegate with a completion handler (callback function)
    init(continuation: CheckedContinuation<PublicKeyCredentialJSON, Error>) {
        self.continuation = continuation
    }

    // Perform the authorization request for a given ASAuthorizationController instance
    func performAuthForController(controller: ASAuthorizationController) {
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return UIApplication
            .shared
            .connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .last ?? ASPresentationAnchor()
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        continuation?.resume(throwing: error)
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {

        switch authorization.credential {
        case let credential as ASAuthorizationPlatformPublicKeyCredentialRegistration:
            self.handlePlatformPublicKeyRegistrationResponse(credential: credential)

        case let credential as ASAuthorizationSecurityKeyPublicKeyCredentialRegistration:
            self.handleSecurityKeyPublicKeyRegistrationResponse(credential: credential)

        case let credential as ASAuthorizationPlatformPublicKeyCredentialAssertion:
            self.handlePlatformPublicKeyAssertionResponse(credential: credential)

        case let credential as ASAuthorizationSecurityKeyPublicKeyCredentialAssertion:
            self.handleSecurityKeyPublicKeyAssertionResponse(credential: credential)
        default:
            continuation?.resume(throwing: ASAuthorizationError(ASAuthorizationError.invalidResponse))
        }
    }

    func handlePlatformPublicKeyRegistrationResponse(
        credential: ASAuthorizationPlatformPublicKeyCredentialRegistration
    ) {
        if credential.rawAttestationObject == nil {
            continuation?.resume(throwing: ASAuthorizationError(ASAuthorizationError.invalidResponse))
            return
        }

        var largeBlob: AuthenticationExtensionsLargeBlobOutputsJSON?
        if #available(iOS 17.0, *) {
            if credential.largeBlob != nil {
                largeBlob = AuthenticationExtensionsLargeBlobOutputsJSON(
                    supported: credential.largeBlob?.isSupported
                )
            }
        }

        let clientExtensionResults = getAuthenticationExtensions(largeBlob)

        guard let attestationObject = credential.rawAttestationObject,
              let publicKey = try? AttestationPublicKeyParser.parse(attestationObjectData: attestationObject) else {
            continuation?.resume(throwing: ASAuthorizationError(ASAuthorizationError.invalidResponse))
            return
        }

        let response =  AuthenticatorAttestationResponseJSON(
            clientDataJSON: credential.rawClientDataJSON,
            publicKey: publicKey, // Use the converted public key
            attestationObject: attestationObject
        )

        let createResponse = RegistrationResponseJSON(
            id: credential.credentialID,
            rawId: credential.credentialID,
            response: response,
            clientExtensionResults: clientExtensionResults
        )

        continuation?.resume(returning: .create(createResponse))
    }

    func handleSecurityKeyPublicKeyRegistrationResponse(
        credential: ASAuthorizationSecurityKeyPublicKeyCredentialRegistration
    ) {
        guard let attestationObject = credential.rawAttestationObject else {
            continuation?.resume(throwing: ASAuthorizationError(ASAuthorizationError.Code.failed))
            return
        }

        var transports: [AuthenticatorTransport] = []

        // Credential transports is only available on iOS 17.5+, so we need to check it here
        // If device is running <17.5, return an empty array
        if #available(iOS 17.5, *) {
            transports = credential.transports.compactMap { transport in
                AuthenticatorTransport(rawValue: transport.rawValue)
            }
        }

        let response =  AuthenticatorAttestationResponseJSON(
            clientDataJSON: credential.rawClientDataJSON,
            transports: transports,
            attestationObject: attestationObject
        )

        let createResponse = RegistrationResponseJSON(
            id: credential.credentialID,
            rawId: credential.credentialID,
            response: response
        )

        continuation?.resume(returning: .create(createResponse))
    }

    func handlePlatformPublicKeyAssertionResponse(credential: ASAuthorizationPlatformPublicKeyCredentialAssertion) {
        var largeBlob: AuthenticationExtensionsLargeBlobOutputsJSON? = AuthenticationExtensionsLargeBlobOutputsJSON()
        if #available(iOS 17.0, *), let result = credential.largeBlob?.result {
            switch result {
            case .read(data: let blobData):
                if let blob = blobData?.uIntArray {
                    largeBlob?.blob = blob
                }
            case .write(success: let successfullyWritten):
                largeBlob?.written = successfullyWritten
            @unknown default: break
            }
        }

        let clientExtensionResults = AuthenticationExtensionsClientOutputsJSON(largeBlob: largeBlob)
        let userHandle: String? = credential.userID.flatMap { String(data: $0, encoding: .utf8) }

        guard let signature = credential.signature else {
            continuation?.resume(throwing: ASAuthorizationError(ASAuthorizationError.Code.failed))
            return
        }

        let response = AuthenticatorAssertionResponseJSON(
            authenticatorData: credential.rawAuthenticatorData,
            clientDataJSON: credential.rawClientDataJSON,
            signature: signature,
            userHandle: userHandle,
            attestationObject: nil
        )

        let getResponse = AuthenticationResponseJSON(
            id: credential.credentialID,
            rawId: credential.credentialID,
            authenticatorAttachment: nil,
            response: response,
            clientExtensionResults: clientExtensionResults
        )

        continuation?.resume(returning: .get(getResponse))
    }

    func handleSecurityKeyPublicKeyAssertionResponse(
        credential: ASAuthorizationSecurityKeyPublicKeyCredentialAssertion
    ) {
        let userHandle: String? = credential.userID.flatMap { String(data: $0, encoding: .utf8) }

        guard let signature = credential.signature else {
            continuation?.resume(throwing: ASAuthorizationError(ASAuthorizationError.Code.failed))
            return
        }

        let response =  AuthenticatorAssertionResponseJSON(
            authenticatorData: credential.rawAuthenticatorData,
            clientDataJSON: credential.rawClientDataJSON,
            signature: signature,
            userHandle: userHandle,
            attestationObject: nil
        )

        let getResponse = AuthenticationResponseJSON(
            id: credential.credentialID,
            rawId: credential.credentialID,
            authenticatorAttachment: nil,
            response: response,
            clientExtensionResults: nil
        )

        continuation?.resume(returning: .get(getResponse))
    }

    private func getAuthenticationExtensions(
        _ largeBlob: AuthenticationExtensionsLargeBlobOutputsJSON?
    ) -> AuthenticationExtensionsClientOutputsJSON? {
        return (largeBlob != nil) ? AuthenticationExtensionsClientOutputsJSON(largeBlob: largeBlob) : nil
    }
}
