import CrossmintService
import Foundation
import SwiftUI
import Testing
@testable import CrossmintClient

let STAGING_KEY = "ck_staging_\(UUID().uuidString)"

struct WalletFailure: LocalizedError {
    let errorDescription: String?
}

enum PayerOutcome: Sendable {
    case returns(String)
    case fails(any Error)

    func value() throws -> String {
        switch self {
        case .returns(let value): value
        case .fails(let error): throw error
        }
    }
}

struct Reply: Decodable, Equatable, Sendable {
    let event: String
    let data: Payload

    struct Payload: Decodable, Equatable, Sendable {
        var txId: String?
        var signature: String?
        var error: String?
        var rejected: Bool?
    }
}

@MainActor
func makeOfframp(
    payer: EmbeddedOfframpPayer = EmbeddedOfframpPayer(signAndSendTransaction: { _ in UUID().uuidString }),
    appearance: (any Encodable)? = nil,
    fill: Bool = false
) -> CrossmintEmbeddedOfframp {
    CrossmintEmbeddedOfframp(
        credentials: EmbeddedOfframpCredentials(sessionId: UUID().uuidString, clientSecret: UUID().uuidString),
        payer: payer,
        appearance: appearance,
        fill: fill
    )
}

@MainActor
func makePageURL(for offramp: CrossmintEmbeddedOfframp, key: String = STAGING_KEY) throws -> URL {
    let apiBaseURL = try DefaultRequestBuilder().getApiBaseURL(forApiKey: try ApiKey(key: key))
    return try #require(offramp.pageURL(apiKey: key, apiBaseURL: apiBaseURL))
}

@MainActor
func makeBridge(
    for offramp: CrossmintEmbeddedOfframp,
    height: Binding<CGFloat> = .constant(0)
) throws -> EmbeddedOfframpBridge {
    EmbeddedOfframpBridge(host: OfframpWebView(page: try makePageURL(for: offramp), offramp: offramp, height: height))
}

func makeMessage(_ event: String, _ data: [String: String]) throws -> String {
    struct Message: Encodable {
        let event: String
        let data: [String: String]
    }
    return try #require(String(data: try JSONEncoder().encode(Message(event: event, data: data)), encoding: .utf8))
}

func makeSendTransactionRequest() throws -> String {
    try makeMessage("crypto:send-transaction", [
        "serializedTransaction": UUID().uuidString,
        "chain": "base-sepolia",
        "payerAddress": UUID().uuidString
    ])
}

func makeSignMessageRequest() throws -> String {
    try makeMessage("crypto:sign-message", [
        "message": UUID().uuidString,
        "chain": "solana",
        "payerAddress": UUID().uuidString
    ])
}

/// Reads a query value the way the page does: URLSearchParams decodes `+` as a space.
func searchParam(_ name: String, in url: URL) throws -> String? {
    let query = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedQuery)
    for pair in query.split(separator: "&") {
        let parts = pair.split(separator: "=", maxSplits: 1)
        guard parts.first.map(String.init) == name, parts.count == 2 else { continue }
        return String(parts[1]).replacingOccurrences(of: "+", with: " ").removingPercentEncoding
    }
    return nil
}
