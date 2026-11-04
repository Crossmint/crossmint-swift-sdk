//
//  SignerOriginTests.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 04/11/26.
//

import Foundation
import Testing
@testable import Web

@Suite("Signer origin", .tags(.unit))
struct SignerOriginTests {
    static let PRODUCTION_SIGNER_URL = "https://signers.crossmint.com?deviceStorage=memory"
    static let STAGING_SIGNER_URL = "https://staging.signers.crossmint.com?deviceStorage=memory"

    struct OriginCase: Sendable, CustomTestStringConvertible {
        let signer: String
        let candidate: String?
        let sameOrigin: Bool

        var testDescription: String {
            "\(candidate ?? "nil") \(sameOrigin ? "on" : "off") \(signer)"
        }
    }

    static let CASES: [OriginCase] = [PRODUCTION_SIGNER_URL, STAGING_SIGNER_URL].flatMap { signer in
        let host = signer == PRODUCTION_SIGNER_URL ? "signers.crossmint.com" : "staging.signers.crossmint.com"
        let otherHost = signer == PRODUCTION_SIGNER_URL ? "staging.signers.crossmint.com" : "signers.crossmint.com"
        let accepted = [
            "https://\(host)",
            "https://\(host)/",
            "https://\(host)/some/path?query=1#fragment",
            "HTTPS://\(host.uppercased())/",
            "https://\(host):443/",
            signer
        ]
        let rejected: [String?] = [
            nil,
            "about:blank",
            "about:srcdoc",
            "data:text/html,<p>\(host)</p>",
            "javascript:alert(1)",
            "file:///\(host)/index.html",
            "http://\(host)/",
            "http://\(host):443/",
            "https://\(host).evil.com/",
            "https://evil.com/\(host)",
            "https://evil.com/?\(host)",
            "https://\(host)@evil.com/",
            "https://user:password@\(host)/",
            "https://\(host):8443/",
            "https://\(host):80/",
            "wss://\(host)/",
            "https://\(otherHost)/"
        ]
        return accepted.map { OriginCase(signer: signer, candidate: $0, sameOrigin: true) }
            + rejected.map { OriginCase(signer: signer, candidate: $0, sameOrigin: false) }
    }

    @Test(arguments: CASES)
    func matchesOnlyTheSignerOrigin(_ originCase: OriginCase) throws {
        let origin = try #require(SignerOrigin(url: URL(string: originCase.signer)))
        let candidate = originCase.candidate.flatMap { URL(string: $0) }

        #expect(origin.contains(candidate) == originCase.sameOrigin)
    }

    @Test(arguments: [
        "http://signers.crossmint.com",
        "about:blank",
        "data:text/html,hi",
        "file:///signers.crossmint.com"
    ])
    func hasNoOriginForANonHttpsSigner(_ signer: String) {
        #expect(SignerOrigin(url: URL(string: signer)) == nil)
    }

    @Test func hasNoOriginWithoutAURL() {
        #expect(SignerOrigin(url: nil) == nil)
    }

    @Test(arguments: [0, 443])
    func treatsAFrameOriginWithTheDefaultPortAsTheSigner(_ port: Int) throws {
        let signer = try #require(SignerOrigin(url: URL(string: Self.PRODUCTION_SIGNER_URL)))

        #expect(SignerOrigin(scheme: "https", host: "signers.crossmint.com", port: port) == signer)
    }

    @Test func rejectsAFrameOriginOnAnotherPort() throws {
        let signer = try #require(SignerOrigin(url: URL(string: Self.PRODUCTION_SIGNER_URL)))

        #expect(SignerOrigin(scheme: "https", host: "signers.crossmint.com", port: 8443) != signer)
    }

    @Test(arguments: [
        (PRODUCTION_SIGNER_URL, "https://signers.crossmint.com"),
        ("https://signers.crossmint.com:8443/", "https://signers.crossmint.com:8443")
    ])
    func formatsTheOriginTheWayBrowsersReportIt(_ signer: String, _ webOrigin: String) throws {
        let origin = try #require(SignerOrigin(url: URL(string: signer)))

        #expect(origin.webOrigin == webOrigin)
    }
}
