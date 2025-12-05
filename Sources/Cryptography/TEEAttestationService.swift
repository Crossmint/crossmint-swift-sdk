import CryptoKit
import Foundation

public struct AttestationResponse: Codable, Sendable {
    public let publicKey: String
    public let timestamp: Int
    public let quote: String
    public let eventLog: String
    public let hashAlgorithm: String
    public let prefix: String

    enum CodingKeys: String, CodingKey {
        case publicKey
        case timestamp
        case quote
        case eventLog = "event_log"
        case hashAlgorithm = "hash_algorithm"
        case prefix
    }
}

public struct TEEReportData: Sendable {
    public let reportData: String
    public let rtMr3: String
}

public enum TEEAttestationError: Error, Equatable {
    case notInitialized
    case attestationFetchFailed(String)
    case verificationFailed(String)
    case invalidPublicKey
    case publicKeyImportFailed
    case attestationExpired
}

public protocol TEEQuoteVerifier: Sendable {
    func verifyTEEReportAndExtractTD(quote: String) async throws -> TEEReportData
}

public actor TEEAttestationService {
    private let apiBaseURL: URL
    private let verifier: TEEQuoteVerifier
    private var publicKey: P256.KeyAgreement.PublicKey?

    private static let teeReportDataPrefix = "app-data:"
    private static let teeReportExpiryMs: Int = 24 * 60 * 60 * 1000

    public init(apiBaseURL: URL, verifier: TEEQuoteVerifier) {
        self.apiBaseURL = apiBaseURL
        self.verifier = verifier
    }

    public func initialize() async throws {
        let attestation = try await fetchAttestation()

        let reportData = try await verifier.verifyTEEReportAndExtractTD(quote: attestation.quote)

        try await verifyTEEPublicKey(
            reportData: reportData.reportData,
            publicKey: attestation.publicKey,
            timestamp: attestation.timestamp
        )

        self.publicKey = try importPublicKey(base64Key: attestation.publicKey)
    }

    public func getAttestedPublicKey() throws -> P256.KeyAgreement.PublicKey {
        guard let publicKey = publicKey else {
            throw TEEAttestationError.notInitialized
        }
        return publicKey
    }

    private func fetchAttestation() async throws -> AttestationResponse {
        let url = apiBaseURL.appendingPathComponent("attestation")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw TEEAttestationError.attestationFetchFailed("HTTP request failed")
        }

        let decoder = JSONDecoder()
        return try decoder.decode(AttestationResponse.self, from: data)
    }

    private func verifyTEEPublicKey(
        reportData: String,
        publicKey: String,
        timestamp: Int
    ) async throws {
        let currentTime = Int(Date().timeIntervalSince1970 * 1000)
        if currentTime - timestamp > Self.teeReportExpiryMs {
            throw TEEAttestationError.attestationExpired
        }

        let isValid = try await verifyReportAttestsPublicKey(
            reportData: reportData,
            publicKey: publicKey,
            timestamp: timestamp
        )

        if !isValid {
            throw TEEAttestationError.verificationFailed(
                "TEE reported public key does not match attestation report"
            )
        }
    }

    private func verifyReportAttestsPublicKey(
        reportData: String,
        publicKey: String,
        timestamp: Int
    ) async throws -> Bool {
        guard let reportDataHash = Data(hexString: reportData) else {
            return false
        }

        if reportDataHash.count != 64 {
            return false
        }

        let attestedData: [String: Any] = [
            "publicKey": publicKey,
            "timestamp": timestamp
        ]

        guard let attestedDataJson = try? JSONSerialization.data(
            withJSONObject: attestedData,
            options: [.sortedKeys]
        ) else {
            return false
        }

        let prefixData = Self.teeReportDataPrefix.data(using: .utf8) ?? Data()
        var reconstructedReportData = prefixData
        reconstructedReportData.append(attestedDataJson)

        let hash = SHA512.hash(data: reconstructedReportData)
        let hashData = Data(hash)

        return hashData == reportDataHash
    }

    private func importPublicKey(base64Key: String) throws -> P256.KeyAgreement.PublicKey {
        guard let keyData = Data(base64Encoded: base64Key) else {
            throw TEEAttestationError.invalidPublicKey
        }

        do {
            return try P256.KeyAgreement.PublicKey(x963Representation: keyData)
        } catch {
            do {
                return try P256.KeyAgreement.PublicKey(rawRepresentation: keyData)
            } catch {
                throw TEEAttestationError.publicKeyImportFailed
            }
        }
    }
}

private extension Data {
    init?(hexString: String) {
        var hex = hexString
        if hex.hasPrefix("0x") {
            hex = String(hex.dropFirst(2))
        }

        guard hex.count % 2 == 0 else { return nil }

        var data = Data()
        var index = hex.startIndex

        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<nextIndex], radix: 16) else {
                return nil
            }
            data.append(byte)
            index = nextIndex
        }

        self = data
    }
}
