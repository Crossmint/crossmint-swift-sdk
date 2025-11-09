import Foundation
import Web
@testable import Wallet

enum CrossmintTEETestHelpers {

    static func createHandshakeRequest(verificationId: String = "test123") -> HandshakeRequest {
        HandshakeRequest(requestVerificationId: verificationId)
    }

    static func createHandshakeResponse(verificationId: String = "test123") -> HandshakeResponse {
        let json = """
        {"event":"handshakeResponse","data":{"requestVerificationId":"\(verificationId)"}}
        """
        let data = Data(json.utf8)
        // swiftlint:disable:next force_try
        return try! JSONDecoder().decode(HandshakeResponse.self, from: data)
    }

    static func createHandshakeComplete(verificationId: String = "test123") -> HandshakeComplete {
        HandshakeComplete(requestVerificationId: verificationId)
    }

    static func createGetStatusResponse(
        status: ResponseStatus = .success,
        signerStatus: SignerStatus? = .ready,
        errorMessage: String? = nil
    ) -> GetStatusResponse {
        let signerStatusJson = signerStatus.map { ",\"signerStatus\":\"\($0.rawValue)\"" } ?? ""
        let errorJson = errorMessage.map { ",\"error\":\"\($0)\"" } ?? ""

        let json = """
        {"event":"response:get-status","data":{"status":"\(status.rawValue)"\(signerStatusJson)\(errorJson)}}
        """

        let data = Data(json.utf8)
        // swiftlint:disable:next force_try
        return try! JSONDecoder().decode(GetStatusResponse.self, from: data)
    }

    static func createStartOnboardingResponse(
        status: ResponseStatus = .success,
        errorMessage: String? = nil
    ) -> StartOnboardingResponse {
        let errorJson = errorMessage.map { ",\"error\":\"\($0)\"" } ?? ""

        let json = """
        {"event":"response:start-onboarding","data":{"status":"\(status.rawValue)"\(errorJson)}}
        """

        let data = Data(json.utf8)
        // swiftlint:disable:next force_try
        return try! JSONDecoder().decode(StartOnboardingResponse.self, from: data)
    }

    static func createCompleteOnboardingResponse(
        status: ResponseStatus = .success,
        errorMessage: String? = nil
    ) -> CompleteOnboardingResponse {
        let errorJson = errorMessage.map { ",\"error\":\"\($0)\"" } ?? ""

        let json = """
        {"event":"response:complete-onboarding","data":{"status":"\(status.rawValue)"\(errorJson)}}
        """

        let data = Data(json.utf8)
        // swiftlint:disable:next force_try
        return try! JSONDecoder().decode(CompleteOnboardingResponse.self, from: data)
    }

    static func createNonCustodialSignResponse(
        signature: String = "0xabcdef123456",
        status: ResponseStatus = .success,
        errorMessage: String? = nil
    ) -> NonCustodialSignResponse {
        let signatureJson = (!signature.isEmpty && status == .success)
            ? ",\"signature\":{\"bytes\":\"\(signature)\",\"encoding\":\"hex\",\"keyType\":\"secp256k1\"}"
            : ""
        let errorJson = errorMessage.map { ",\"error\":\"\($0)\"" } ?? ""

        let json = """
        {"event":"response:sign","data":{"status":"\(status.rawValue)"\(signatureJson)\(errorJson)}}
        """

        let data = Data(json.utf8)
        // swiftlint:disable:next force_try
        return try! JSONDecoder().decode(NonCustodialSignResponse.self, from: data)
    }

    static func createTestJWT() -> String {
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJlbWFpbCI6InRlc3RAZXhhbXBsZS5jb20ifQ.test"
    }

    static func createTestTransaction() -> String {
        "0x52769994aa43c041dad4d211d584bef75e03b318dc8d34a449f815aeb50b99c8"
    }
}
