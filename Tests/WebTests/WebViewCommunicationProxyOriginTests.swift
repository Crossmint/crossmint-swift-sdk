//
//  WebViewCommunicationProxyOriginTests.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 30/10/26.
//

import Foundation
import Testing
import WebKit
@testable import Web

@Suite("Signer page origin", .tags(.unit), .timeLimit(.minutes(1)))
@MainActor
struct WebViewCommunicationProxyOriginTests {
    @Test func deliversMainFrameMessagesFromLoadedOrigin() async throws {
        let fixture = SignerPageFixture()

        try await fixture.proxy.loadURL(#require(URL(string: SignerPageFixture.SIGNER_URL)))
        await fixture.recorder.wait(for: "from.signer")

        #expect(fixture.recorder.types == ["from.signer"])
    }

    @Test func dropsMessagesFromForeignPageAndItsIframe() async throws {
        let fixture = SignerPageFixture()
        try await fixture.proxy.loadURL(#require(URL(string: SignerPageFixture.SIGNER_URL)))
        await fixture.recorder.wait(for: "from.signer")

        fixture.webView.navigationDelegate = nil
        try fixture.webView.load(URLRequest(url: #require(URL(string: SignerPageFixture.FOREIGN_URL))))
        await fixture.recorder.wait(for: "foreign.done")

        fixture.webView.navigationDelegate = fixture.navigation
        try fixture.webView.load(URLRequest(url: #require(URL(string: SignerPageFixture.SIGNER_SECOND_PAGE_URL))))
        await fixture.recorder.wait(for: "from.signer.second")

        #expect(fixture.recorder.types == ["from.signer", "foreign.done", "from.signer.second"])
    }

    @Test(arguments: [
        "crossmint-test://foreign/",
        "https://signer/",
        "crossmint-test://signer:8080/"
    ])
    func cancelsSignerPageNavigationToAnotherOrigin(_ url: String) async throws {
        let fixture = SignerPageFixture()
        try await fixture.proxy.loadURL(#require(URL(string: SignerPageFixture.SIGNER_URL)))

        _ = try await fixture.webView.evaluateJavaScript("location.href = \"\(url)\"; true")

        #expect(await fixture.navigation.policy(for: url) == .cancel)
    }

    @Test func cancelsNavigationBeforeTheSignerPageLoads() async throws {
        let fixture = SignerPageFixture()

        try fixture.webView.load(URLRequest(url: #require(URL(string: SignerPageFixture.SIGNER_URL))))

        #expect(await fixture.navigation.policy(for: SignerPageFixture.SIGNER_URL) == .cancel)
    }
}
