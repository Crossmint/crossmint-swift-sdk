import Foundation
import Http

public struct UnstubbedRequest: LocalizedError, Sendable {
    public let method: String
    public let url: String

    public var errorDescription: String? {
        "No fixture for \(method) \(url). Stub it with HTTPFixtureRouter.respond(to:path:status:body:)."
    }
}

public final class HTTPFixtureRouter: @unchecked Sendable {
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

    public init() {
        NetworkKillSwitch.install()
    }

    public var requests: [URLRequest] {
        lock.withLock { recorded }
    }

    public var lastRequest: URLRequest? {
        requests.last
    }

    public func respond(to method: String? = nil, path: String? = nil, status: Int = 200, body: Data = Data()) {
        lock.withLock { rules.append(Rule(method: method, path: path, status: status, body: body)) }
    }

    public func respond(to method: String? = nil, path: String? = nil, status: Int = 200, json: String) {
        respond(to: method, path: path, status: status, body: Data(json.utf8))
    }

    public var client: HTTPClient {
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

/// Fails any request that reaches `URLSession.shared` in a test process, naming the request.
public class NetworkKillSwitch: URLProtocol {
    private static let installation: Void = { URLProtocol.registerClass(NetworkKillSwitch.self) }()

    public static func install() {
        _ = installation
    }

    override public class func canInit(with request: URLRequest) -> Bool { true }
    override public class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override public func startLoading() {
        let unstubbed = UnstubbedRequest(method: request.httpMethod ?? "GET", url: request.url?.absoluteString ?? "")
        client?.urlProtocol(self, didFailWithError: NSError(
            domain: "NetworkKillSwitch",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: unstubbed.errorDescription ?? ""]
        ))
    }

    override public func stopLoading() {}
}
