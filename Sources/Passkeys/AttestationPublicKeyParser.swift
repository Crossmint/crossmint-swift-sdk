import Foundation
import SwiftCBOR
import Utils
import BigInt

public struct ParsedPublicKeyP256: Sendable {
    public let prefix: String = "0x04" // Standard prefix for uncompressed P-256 keys
    public let x: String // Base64URL encoded x-coordinate
    public let y: String // Base64URL encoded y-coordinate
}

public enum AttestationParsingError: Error {
    case cborDecodingFailed(description: String)
    case invalidAttestationObject(description: String)
    case authDataTooShort
    case attestedCredentialDataMissing
    case coseKeyDecodingFailed
    case invalidCoseKeyFormat
    case coordinateExtractionFailed
    case invalidCoordinateData
}

public struct AttestationPublicKeyParser {
    public static func parse(attestationObjectData: Data) throws -> ParsedPublicKeyP256 {
        guard let attestationCbor = try? CBOR.decode([UInt8](attestationObjectData)) else {
            throw AttestationParsingError.cborDecodingFailed(
                description: "Failed to decode top-level attestation object."
            )
        }

        guard let authDataCbor = attestationCbor["authData"],
              case let .byteString(authDataBytes) = authDataCbor else {
            throw AttestationParsingError.invalidAttestationObject(
                description: "Missing or invalid 'authData' in attestation object."
            )
        }

        let result = AuthData(bytes: authDataBytes).validateSize()
            .flatMap { $0.validateAttestedCredentialData() }
            .flatMap { $0.extractCoseKey() }
            .flatMap { $0.toParsedPublicKey() }

        switch result {
        case .success(let publicKey):
            return publicKey
        case .failure(let error):
            throw error
        }
    }

    struct AuthData {
        let bytes: [UInt8]

        func validateSize() -> Result<AuthData, AttestationParsingError> {
            // Minimum length for authData (RP ID Hash (32) + Flags (1) + Sign Count (4))
            guard bytes.count >= (32 + 1 + 4) else {
                return .failure(.authDataTooShort)
            }
            return .success(self)
        }

        func validateAttestedCredentialData() -> Result<AuthData, AttestationParsingError> {
            let flags = bytes[32]
            let attestedCredentialDataIncluded = (flags & (1 << 6)) != 0 // Check AT flag (bit 6)

            guard attestedCredentialDataIncluded else {
                return .failure(.attestedCredentialDataMissing)
            }

            // --- Attested Credential Data Parsing ---
            // RP ID Hash (32) | Flags (1) | Sign Counter (4) | AAGUID (16) | CredID Length (2) | CredID (?) | COSE Key (?)
            let minLengthWithAttestedDataHeader = 32 + 1 + 4 + 16 + 2 // authData header + AAGUID + CredID Length
            guard bytes.count > minLengthWithAttestedDataHeader else {
                return .failure(.authDataTooShort)
            }

            return .success(self)
        }

        func extractCoseKey() -> Result<CoseKey, AttestationParsingError> {
            let credIdLengthIndex = 32 + 1 + 4 + 16
            let credIdLength = (UInt16(bytes[credIdLengthIndex]) << 8) | UInt16(bytes[credIdLengthIndex + 1])

            let coseKeyStartIndex = credIdLengthIndex + 2 + Int(credIdLength)
            guard bytes.count > coseKeyStartIndex else {
                return .failure(.authDataTooShort)
            }

            let coseKeyBytes = Array(bytes[coseKeyStartIndex...])
            guard let coseKeyCbor = try? CBOR.decode(coseKeyBytes) else {
                return .failure(.coseKeyDecodingFailed)
            }

            guard case let .map(coseKeyMap) = coseKeyCbor else {
                return .failure(.invalidCoseKeyFormat) // Expected a map
            }

            // Standard keys for EC2 public keys (RFC 8152, Section 7.1, Table 5 & Section 13, Table 22)
            // kty (1): EC2 (2)
            // alg (3): ES256 (-7)
            // crv ( -1): P-256 (1)
            // x   (-2): x-coordinate (byte string)
            // y   (-3): y-coordinate (byte string)

            guard let xCoordCbor = coseKeyMap[CBOR.negativeInt(1)], // Corresponds to key -2
                  let yCoordCbor = coseKeyMap[CBOR.negativeInt(2)], // Corresponds to key -3
                  case let .byteString(xCoordBytes) = xCoordCbor,
                  case let .byteString(yCoordBytes) = yCoordCbor else {
                return .failure(.coordinateExtractionFailed)
            }

            return CoseKey(xCoordBytes: xCoordBytes, yCoordBytes: yCoordBytes).validate()
        }
    }

    struct CoseKey {
        let xCoordBytes: [UInt8]
        let yCoordBytes: [UInt8]

        func validate() -> Result<CoseKey, AttestationParsingError> {
            guard xCoordBytes.count == 32, yCoordBytes.count == 32 else {
                return .failure(.invalidCoordinateData)
            }
            return .success(self)
        }

        func transformToBigIntegers() -> Result<(xInt: BigUInt, yInt: BigUInt), AttestationParsingError> {
            var xInt = BigUInt(0)
            var yInt = BigUInt(0)

            for byte in xCoordBytes {
                xInt = (xInt << 8) | BigUInt(byte)
            }

            for byte in yCoordBytes {
                yInt = (yInt << 8) | BigUInt(byte)
            }

            // P-256 field size (p)
            guard let p256FieldSize = BigUInt(
                "FFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF",
                radix: 16
            ) else {
                return .failure(.invalidCoordinateData)
            }

            // Validate that coordinates are within the valid range for P-256
            guard xInt < p256FieldSize && yInt < p256FieldSize else {
                return .failure(.invalidCoordinateData)
            }

            return .success((xInt, yInt))
        }

        func toParsedPublicKey() -> Result<ParsedPublicKeyP256, AttestationParsingError> {
            return transformToBigIntegers().map { xInt, yInt in
                ParsedPublicKeyP256(
                    x: String(xInt),
                    y: String(yInt)
                )
            }
        }
    }
}

// Extend CBOR dictionary access for convenience
extension CBOR {
    subscript(key: String) -> CBOR? {
        guard case let .map(dict) = self else { return nil }
        return dict[CBOR.utf8String(key)]
    }

    subscript(key: Int) -> CBOR? {
        guard case let .map(dict) = self else { return nil }
        // Allows accessing with negative Int keys like -2, -3
        return dict[CBOR.init(integerLiteral: key)]
    }
}
