import CrossmintService
import Foundation
import Http
import Testing

package struct UnstubbedRequest: CrossmintError {
    package let method: String
    package let url: String

    package var code: String { "UNSTUBBED_REQUEST" }
    package var message: String { "No fixture for \(method) \(url)." }
    package var recoverySuggestion: String? { "Stub it with HTTPFixtureRouter.respond(to:path:status:body:)." }
}

package final class HTTPFixtureRouter: @unchecked Sendable {
    private struct Rule {
        let method: String?
        let path: String?
        let status: Int
        let body: Data

        func matches(method requestMethod: String, path requestPath: String) -> Bool {
            if let method, method.caseInsensitiveCompare(requestMethod) != .orderedSame { return false }
            if let path, !requestPath.hasSuffix(path) { return false }
            return true
        }
    }

    private let lock = NSLock()
    private var rules: [Rule] = []
    private var recorded: [URLRequest] = []

    package init() {
        NetworkKillSwitch.install()
    }

    package var requests: [URLRequest] {
        lock.withLock { recorded }
    }

    package var lastRequest: URLRequest? {
        requests.last
    }

    package func respond(to method: String? = nil, path: String? = nil, status: Int = 200, body: Data = Data()) {
        lock.withLock { rules.append(Rule(method: method, path: path, status: status, body: body)) }
    }

    package func respond(to method: String? = nil, path: String? = nil, status: Int = 200, json: String) {
        respond(to: method, path: path, status: status, body: Data(json.utf8))
    }

    package var client: HTTPClient {
        HTTPClient { [self] request throws(NetworkError) in
            lock.withLock { recorded.append(request) }
            let method = request.httpMethod ?? "GET"
            let url = request.url?.absoluteString ?? ""
            let path = request.url?.path ?? ""
            guard let rule = lock.withLock({ rules.first { $0.matches(method: method, path: path) } }),
                  let requestURL = request.url,
                  let response = HTTPURLResponse(
                      url: requestURL, statusCode: rule.status, httpVersion: nil, headerFields: nil
                  )
            else {
                throw NetworkError.unknown(UnstubbedRequest(method: method, url: url))
            }
            return try HTTPClient.mapStatus(data: rule.body, response: response)
        }
    }
}

/// Fails any request that reaches `URLSession.shared` in a test process. It also records a test issue,
/// so a caller that swallows the error still shows up, except for SDK telemetry and for the guard's own
/// test (`expectBlockedRequest`).
package class NetworkKillSwitch: URLProtocol {
    private static let installation: Void = { URLProtocol.registerClass(NetworkKillSwitch.self) }()
    private static let telemetryHost = "telemetry.crossmint.com"
    private static let lock = NSLock()
    nonisolated(unsafe) private static var expectingBlockedRequest = false

    package static func install() {
        _ = installation
    }

    package static var expectBlockedRequest: Bool {
        get { lock.withLock { expectingBlockedRequest } }
        set { lock.withLock { expectingBlockedRequest = newValue } }
    }

    override package class func canInit(with request: URLRequest) -> Bool { true }
    override package class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override package func startLoading() {
        let unstubbed = UnstubbedRequest(method: request.httpMethod ?? "GET", url: request.url?.absoluteString ?? "")
        if !Self.expectBlockedRequest, request.url?.host != Self.telemetryHost {
            Issue.record("A test reached the network: \(unstubbed.message)")
        }
        client?.urlProtocol(self, didFailWithError: NSError(
            domain: "NetworkKillSwitch",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: unstubbed.description]
        ))
    }

    override package func stopLoading() {}
}
