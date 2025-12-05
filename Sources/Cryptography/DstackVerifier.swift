import Foundation

public struct PhalaQuoteBody: Codable, Sendable {
    public let reportdata: String
    public let rtmr3: String
}

public struct PhalaQuote: Codable, Sendable {
    public let body: PhalaQuoteBody
}

public struct PhalaQuoteResponse: Codable, Sendable {
    public let success: Bool
    public let quote: PhalaQuote
}

public enum DstackVerifierError: Error, Equatable {
    case verificationFailed(String)
    case invalidResponse
    case networkError(String)
}

public struct DstackVerifier: TEEQuoteVerifier, Sendable {
    private static let defaultPhalaApiURL = URL(
        string: "https://cloud-api.phala.com/crossmint/attestations/verify"
    )

    private let phalaApiURL: URL

    public init(phalaApiURL: URL? = nil) {
        if let url = phalaApiURL {
            self.phalaApiURL = url
        } else if let defaultURL = Self.defaultPhalaApiURL {
            self.phalaApiURL = defaultURL
        } else {
            fatalError("Invalid default Phala API URL")
        }
    }

    public func verifyTEEReportAndExtractTD(quote: String) async throws -> TEEReportData {
        let verifiedQuote = try await verifyTEEReport(quote: quote)
        return extractTDFromReport(report: verifiedQuote)
    }

    private func verifyTEEReport(quote: String) async throws -> PhalaQuoteResponse {
        let boundary = UUID().uuidString
        var request = URLRequest(url: phalaApiURL)
        request.httpMethod = "POST"
        request.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField: "Content-Type"
        )

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8) ?? Data())
        body.append(
            "Content-Disposition: form-data; name=\"hex\"\r\n\r\n".data(using: .utf8) ?? Data()
        )
        body.append("\(quote)\r\n".data(using: .utf8) ?? Data())
        body.append("--\(boundary)--\r\n".data(using: .utf8) ?? Data())

        request.httpBody = body

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw DstackVerifierError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw DstackVerifierError.networkError("HTTP request failed")
        }

        let decoder = JSONDecoder()
        let verifiedQuote: PhalaQuoteResponse
        do {
            verifiedQuote = try decoder.decode(PhalaQuoteResponse.self, from: data)
        } catch {
            throw DstackVerifierError.invalidResponse
        }

        if !verifiedQuote.success {
            throw DstackVerifierError.verificationFailed("TEE attestation is invalid")
        }

        return verifiedQuote
    }

    private func extractTDFromReport(report: PhalaQuoteResponse) -> TEEReportData {
        var reportData = report.quote.body.reportdata
        if reportData.hasPrefix("0x") {
            reportData = String(reportData.dropFirst(2))
        }

        var rtMr3 = report.quote.body.rtmr3
        if rtMr3.hasPrefix("0x") {
            rtMr3 = String(rtMr3.dropFirst(2))
        }

        return TEEReportData(reportData: reportData, rtMr3: rtMr3)
    }
}
