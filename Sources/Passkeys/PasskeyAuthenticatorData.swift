import Foundation

public struct PasskeyAuthenticatorData: Codable {
    public let rpIdHash: String
    public let flags: PasskeyAuthenticatorFlags
    public let counter: Int
    public let aaguid: String
    public let credentialID: String
    public let credentialPublicKey: String
    public let parsedCredentialPublicKey: ParsedCredentialPublicKey
}

public struct PasskeyAuthenticatorFlags: Codable {
    public let userPresent: Bool
    public let userVerified: Bool
    public let backupEligible: Bool
    public let backupStatus: Bool
    public let attestedData: Bool
    public let extensionData: Bool
}

public struct ParsedCredentialPublicKey: Codable {
    public let keyType: String
    public let algorithm: String
    public let curve: Int
    public let x: String
    public let y: String
}
