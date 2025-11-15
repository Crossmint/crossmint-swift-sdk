import AuthenticationServices

public class Passkey {
    var passkeyDelegate: PasskeyDelegate?

    public init() {}

    @MainActor
    public func create(
        _ options: PasskeyCredentialCreationOptions,
        forcePlatformKey: Bool,
        forceSecurityKey: Bool
    ) async throws -> PublicKeyCredentialJSON {
        try await withCheckedThrowingContinuation { continuation in
            // Convert challenge to Data
            guard let challenge: Data = Data(base64URLEncoded: options.challenge) else {
                continuation.resume(throwing: PasskeyError(type: .invalidChallenge))
                return
            }

            // Convert userId to Data
            guard let userId: Data = options.user.id.data(using: .utf8) else {
                continuation.resume(throwing: PasskeyError(type: .invalidUser))
                return
            }

            // Create requests
            guard let platformKeyRequest: ASAuthorizationRequest = self.configureCreatePlatformRequest(
                challenge: challenge,
                userId: userId,
                request: options
            ) else {
                continuation.resume(throwing: PasskeyError(type: .badConfiguration))
                return
            }
            guard let securityKeyRequest: ASAuthorizationRequest = self.configureCreateSecurityKeyRequest(
                challenge: challenge,
                userId: userId,
                request: options
            ) else {
                continuation.resume(throwing: PasskeyError(type: .badConfiguration))
                return
            }

            // Get authorization controller
            let authController: ASAuthorizationController = self.configureAuthController(
                forcePlatformKey: forcePlatformKey,
                forceSecurityKey: forceSecurityKey,
                platformKeyRequest: platformKeyRequest,
                securityKeyRequest: securityKeyRequest
            )

            let passkeyDelegate = PasskeyDelegate(continuation: continuation)

            // Keep a reference to the delegate object
            self.passkeyDelegate = passkeyDelegate

            // Perform the authorization
            passkeyDelegate.performAuthForController(controller: authController)
        }
    }

    /**
     Main get entrypoint
     */
    @MainActor
    public func get(
        _ options: PasskeyCredentialRequestOptions,
        forcePlatformKey: Bool,
        forceSecurityKey: Bool
    ) async throws -> PublicKeyCredentialJSON {
        try await withCheckedThrowingContinuation { continuation in
            let challenge = options.challenge

            let platformKeyRequest: ASAuthorizationRequest = self.configureGetPlatformRequest(
                challenge: challenge,
                request: options
            )
            let securityKeyRequest: ASAuthorizationRequest = self.configureGetSecurityKeyRequest(
                challenge: challenge,
                request: options
            )

            // Get authorization controller
            let authController: ASAuthorizationController = self.configureAuthController(
                forcePlatformKey: forcePlatformKey,
                forceSecurityKey: forceSecurityKey,
                platformKeyRequest: platformKeyRequest,
                securityKeyRequest: securityKeyRequest
            )

            let passkeyDelegate = PasskeyDelegate(continuation: continuation)

            // Keep a reference to the delegate object
            self.passkeyDelegate = passkeyDelegate

            // Perform the authorization
            passkeyDelegate.performAuthForController(controller: authController)
        }
    }

    /**
     Creates and returns security key create request
     */
    private func configureCreateSecurityKeyRequest(
        challenge: Data,
        userId: Data,
        request: PasskeyCredentialCreationOptions
    ) -> ASAuthorizationSecurityKeyPublicKeyCredentialRegistrationRequest? {

        guard let rpID = request.rp.id else { return nil }

        let securityKeyProvider = ASAuthorizationSecurityKeyPublicKeyCredentialProvider(
            relyingPartyIdentifier: rpID
        )

        let authRequest = securityKeyProvider.createCredentialRegistrationRequest(challenge: challenge,
                                                                                  displayName: request.user.displayName,
                                                                                  name: request.user.name,
                                                                                  userID: userId)

        authRequest.credentialParameters = request.pubKeyCredParams.map({ $0.appleise() })
        if #available(iOS 17.4, *) {
            if let excludeCredentials = request.excludeCredentials {
                authRequest.excludedCredentials = excludeCredentials.compactMap({ $0.getCrossPlatformDescriptor() })
            }
        }

        if let residentCredPref = request.authenticatorSelection?.residentKey {
            authRequest.residentKeyPreference = residentCredPref.appleise()
        }

        if let userVerificationPref = request.authenticatorSelection?.userVerification {
            authRequest.userVerificationPreference = userVerificationPref.appleise()
        }

        if let rpAttestationPref = request.attestation {
            authRequest.attestationPreference = rpAttestationPref.appleise()
        }

        return authRequest
    }

    /**
     Creates and returns platform key create request
     */
    private func configureCreatePlatformRequest(
        challenge: Data,
        userId: Data,
        request: PasskeyCredentialCreationOptions
    ) -> ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest? {

        guard let rpID = request.rp.id else { return nil }
        let platformProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(
            relyingPartyIdentifier: rpID
        )

        let authRequest = platformProvider.createCredentialRegistrationRequest(
            challenge: challenge,
            name: request.user.name,
            userID: userId
        )

        if #available(iOS 17.0, *) {
            if let largeBlob = request.extensions?.largeBlob {
                authRequest.largeBlob = largeBlob.support?.appleise()
            }
        }

        if #available(iOS 17.4, *) {
            if let excludeCredentials = request.excludeCredentials {
                authRequest.excludedCredentials = excludeCredentials.compactMap({ $0.getPlatformDescriptor() })
            }
        }

        if let userVerificationPref = request.authenticatorSelection?.userVerification {
            authRequest.userVerificationPreference = userVerificationPref.appleise()
        }

        return authRequest
    }

    /**
     Creates and returns platform key get request
     */
    private func configureGetPlatformRequest(
        challenge: Data,
        request: PasskeyCredentialRequestOptions
    ) -> ASAuthorizationPlatformPublicKeyCredentialAssertionRequest {

        let platformProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: request.rpId)
        let authRequest = platformProvider.createCredentialAssertionRequest(challenge: challenge)

        if #available(iOS 17.0, *) {
            if request.extensions?.largeBlob?.read == true {
                authRequest.largeBlob = ASAuthorizationPublicKeyCredentialLargeBlobAssertionInput.read
            }

            if let largeBlobWriteData = request.extensions?.largeBlob?.write {
                authRequest.largeBlob = ASAuthorizationPublicKeyCredentialLargeBlobAssertionInput.write(
                    largeBlobWriteData
                )
            }
        }

        if let allowCredentials = request.allowCredentials {
            authRequest.allowedCredentials = allowCredentials.compactMap({ $0.getPlatformDescriptor() })
        }

        if let userVerificationPref = request.userVerification {
            authRequest.userVerificationPreference = userVerificationPref.appleise()
        }

        return authRequest
    }

    /**
     Creates and returns security key get request
     */
    private func configureGetSecurityKeyRequest(
        challenge: Data,
        request: PasskeyCredentialRequestOptions
    ) -> ASAuthorizationSecurityKeyPublicKeyCredentialAssertionRequest {

        let securityKeyProvider = ASAuthorizationSecurityKeyPublicKeyCredentialProvider(
            relyingPartyIdentifier: request.rpId
        )

        let authRequest = securityKeyProvider.createCredentialAssertionRequest(challenge: challenge)

        if let allowCredentials = request.allowCredentials {
            authRequest.allowedCredentials = allowCredentials.compactMap({ $0.getCrossPlatformDescriptor() })
        }

        if let userVerificationPref = request.userVerification {
            authRequest.userVerificationPreference = userVerificationPref.appleise()
        }

        return authRequest
    }

    /**
     Creates and returns authorization controller depending on selected request types
     */
    private func configureAuthController(
        forcePlatformKey: Bool,
        forceSecurityKey: Bool,
        platformKeyRequest: ASAuthorizationRequest,
        securityKeyRequest: ASAuthorizationRequest
    ) -> ASAuthorizationController {
        if forcePlatformKey {
            return ASAuthorizationController(authorizationRequests: [platformKeyRequest])
        }

        if forceSecurityKey {
            return ASAuthorizationController(authorizationRequests: [securityKeyRequest])
        }

        return ASAuthorizationController(authorizationRequests: [platformKeyRequest, securityKeyRequest])
    }
}
