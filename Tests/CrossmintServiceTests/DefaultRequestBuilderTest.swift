import Testing
@testable import CrossmintService

struct DefaultRequestBuilderTest {

    // swiftlint:disable:next force_try
    private let apiKey = try! ApiKey(key: "sk_staging_abc")

    private let requestBuilder = DefaultRequestBuilder()

    @Test("Uses api key environment to build the path")
    func usesApiKeyEnvironmentToBuildThePath() throws {
        let request = try requestBuilder.getRequest(
            forEndpoint: .init(
                path: "/x/y/z",
                method: .get
            ),
            // swiftlint:disable:next force_try
            withKey: try! ApiKey(key: "sk_production_abc"),
            andAppIdentifier: "App-Identifier"
        )

        #expect(request.url?.absoluteString == "https://www.crossmint.com/api/x/y/z?")
    }

    @Test("Handle path with query items")
    func handlePathWithQueryItems() throws {
        let request = try requestBuilder.getRequest(
            forEndpoint: .init(
                path: "/x/y/z",
                method: .get,
                queryItems: [.init(name: "query_item", value: "item_value")]
            ),
            withKey: apiKey,
            andAppIdentifier: "App-Identifier"
        )

        #expect(request.url?.absoluteString == "https://staging.crossmint.com/api/x/y/z?query_item=item_value")
    }

    @Test("Handle headers")
    func handleHeaders() throws {
        let request = try requestBuilder.getRequest(
            forEndpoint: .init(
                path: "/x/y/z",
                method: .get,
                headers: ["custom-header": "header-value"]
            ),
            withKey: apiKey,
            andAppIdentifier: "App-Identifier"
        )

        #expect(request.allHTTPHeaderFields?["Content-Type"] == "application/json")
        #expect(request.allHTTPHeaderFields?["X-API-KEY"] == "sk_staging_abc")
        #expect(request.allHTTPHeaderFields?["custom-header"] == "header-value")
        #expect(request.allHTTPHeaderFields?["X-APP-IDENTIFIER"] == "App-Identifier")
        #expect(request.allHTTPHeaderFields?.count == 4)
    }

    @Test("Can override headers")
    func canOverrideHeaders() throws {
        let request = try requestBuilder.getRequest(
            forEndpoint: .init(
                path: "/x/y/z",
                method: .get,
                headers: ["Content-Type": "application/xml"]
            ),
            withKey: apiKey,
            andAppIdentifier: "App-Identifier"
        )

        #expect(request.allHTTPHeaderFields?["Content-Type"] == "application/xml")
    }

    @Test("Get request")
    func getRequest() throws {
        let request = try requestBuilder.getRequest(
            forEndpoint: .init(
                path: "/x/y/z",
                method: .get
            ),
            withKey: apiKey,
            andAppIdentifier: "App-Identifier"
        )

        #expect(request.httpMethod == "GET")
    }

    @Test("Post request")
    func postRequest() throws {
        let request = try requestBuilder.getRequest(
            forEndpoint: .init(
                path: "/x/y/z",
                method: .post
            ),
            withKey: apiKey,
            andAppIdentifier: "App-Identifier"
        )

        #expect(request.httpMethod == "POST")
    }
}
