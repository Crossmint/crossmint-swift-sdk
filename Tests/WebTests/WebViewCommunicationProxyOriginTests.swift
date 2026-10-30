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

        fixture.webView.navigationDelegate = fixture.proxy
        try fixture.webView.load(URLRequest(url: #require(URL(string: SignerPageFixture.SIGNER_SECOND_PAGE_URL))))
        await fixture.recorder.wait(for: "from.signer.second")

        #expect(fixture.recorder.types == ["from.signer", "foreign.done", "from.signer.second"])
    }

    struct NavigationCase: Sendable, CustomTestStringConvertible {
        let url: String
        let mainFrame: Bool
        let allowed: Bool

        var testDescription: String { "\(url) in \(mainFrame ? "main frame" : "subframe")" }
    }

    @Test(arguments: [
        NavigationCase(url: "crossmint-test://signer/second", mainFrame: true, allowed: true),
        NavigationCase(url: "crossmint-test://foreign/", mainFrame: true, allowed: false),
        NavigationCase(url: "https://signer/", mainFrame: true, allowed: false),
        NavigationCase(url: "crossmint-test://signer:8080/", mainFrame: true, allowed: false),
        NavigationCase(url: "crossmint-test://foreign/", mainFrame: false, allowed: true)
    ])
    func allowsMainFrameNavigationOnlyWithinLoadedOrigin(_ navigation: NavigationCase) async throws {
        let fixture = SignerPageFixture()
        try await fixture.proxy.loadURL(#require(URL(string: SignerPageFixture.SIGNER_URL)))
        let url = try #require(URL(string: navigation.url))

        #expect(fixture.proxy.allowsNavigation(to: url, inMainFrame: navigation.mainFrame) == navigation.allowed)
    }

    @Test func blocksMainFrameNavigationBeforeAnyPageLoads() throws {
        let fixture = SignerPageFixture()
        let url = try #require(URL(string: SignerPageFixture.SIGNER_URL))

        #expect(!fixture.proxy.allowsNavigation(to: url, inMainFrame: true))
    }
}
