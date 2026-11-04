import Foundation
import Testing
@testable import CrossmintClient

@Suite("Embedded offramp page URL", .tags(.unit))
@MainActor
struct EmbeddedOfframpPageURLTests {
    @Test(arguments: [("ck_staging_x", "staging.crossmint.com"), ("ck_production_x", "www.crossmint.com")])
    func pointsAtTheEnvironmentOfTheKey(key: String, host: String) throws {
        let url = try makePageURL(for: makeOfframp(), key: key)

        #expect(url.host == host)
        #expect(url.path == "/sdk/unstable/embedded-offramp")
        #expect(try searchParam("apiKey", in: url) == key)
    }

    @Test func keepsReservedCharactersForTheQueryParserOfThePage() throws {
        let credentials = EmbeddedOfframpCredentials(sessionId: "a+b&c=d", clientSecret: "e/f#g?h i")
        let view = CrossmintEmbeddedOfframp(
            credentials: credentials,
            payer: EmbeddedOfframpPayer(signAndSendTransaction: { _ in "" }),
            appearance: ["fonts": [["cssSrc": "https://fonts.googleapis.com/css2?family=Open+Sans"]]]
        )

        let url = try makePageURL(for: view)

        let sent = try JSONDecoder().decode(
            EmbeddedOfframpCredentials.self, from: Data(try #require(try searchParam("credentials", in: url)).utf8)
        )
        #expect(sent.sessionId == credentials.sessionId)
        #expect(sent.clientSecret == credentials.clientSecret)
        #expect(try searchParam("appearance", in: url)?.contains("Open+Sans") == true)
    }

    @Test(arguments: [true, false])
    func announcesMessageSigningOnlyForAPayerThatSignsMessages(signs: Bool) throws {
        let payer = EmbeddedOfframpPayer(
            signAndSendTransaction: { _ in "" },
            signMessage: signs ? { @MainActor _ in "" } : nil
        )

        let url = try makePageURL(for: makeOfframp(payer: payer))

        #expect(try searchParam("canSignMessage", in: url) == (signs ? "true" : nil))
    }

    @Test(arguments: [true, false])
    func asksThePageToFillOnlyWhenFilling(fill: Bool) throws {
        let url = try makePageURL(for: makeOfframp(fill: fill))

        #expect(try searchParam("fill", in: url) == (fill ? "true" : nil))
    }
}
