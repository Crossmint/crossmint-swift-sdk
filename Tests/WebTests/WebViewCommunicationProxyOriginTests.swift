//
//  WebViewCommunicationProxyOriginTests.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 04/11/26.
//

import Foundation
import Testing
import WebKit
@testable import Web

@Suite("Signer web view origin", .tags(.unit), .timeLimit(.minutes(1)))
@MainActor
struct WebViewCommunicationProxyOriginTests {
    @Suite("Sending messages")
    @MainActor
    struct SendingTests {
        @Test func sendsToTheSignerPage() async throws {
            let fixture = SignerPageFixture()
            try await fixture.proxy.loadURL(fixture.url(SignerPageFixture.SIGNER_URL))

            try await fixture.proxy.sendMessage(ProbeMessage(type: "native.hello"))

            let received = try await fixture.evaluate("window.received.type") as? String
            #expect(received == "native.hello")
        }

        @Test func refusesToSendWhenThePageLeftTheSignerOrigin() async throws {
            let fixture = SignerPageFixture()
            try await fixture.proxy.loadURL(fixture.url(SignerPageFixture.SIGNER_URL))
            try await fixture.showWithoutProxy(SignerPageFixture.FOREIGN_URL)

            await #expect(throws: WebViewError.webViewNotAvailable) {
                _ = try await fixture.proxy.sendMessage(ProbeMessage(type: "native.hello"))
            }

            let received = try await fixture.evaluate("window.received === undefined") as? Bool
            #expect(received == true)
        }
    }

    @Suite("Navigation policy")
    @MainActor
    struct NavigationTests {
        @Test func blocksAMainFrameNavigationOffTheSignerOrigin() async throws {
            let fixture = SignerPageFixture()
            try await fixture.proxy.loadURL(fixture.url(SignerPageFixture.SIGNER_URL))
            let foreign = try fixture.url(SignerPageFixture.FOREIGN_URL)

            fixture.webView.load(URLRequest(url: foreign))
            await fixture.navigations.wait { $0 == .decided(url: foreign, isMainFrame: true, policy: .cancel) }

            #expect(!fixture.navigations.events.contains(.decided(url: foreign, isMainFrame: true, policy: .allow)))
        }

        @Test func keepsTheSignerPageReadyAfterABlockedNavigation() async throws {
            let fixture = SignerPageFixture()
            try await fixture.proxy.loadURL(fixture.url(SignerPageFixture.SIGNER_URL))
            let foreign = try fixture.url(SignerPageFixture.FOREIGN_URL)

            fixture.webView.load(URLRequest(url: foreign))
            await fixture.navigations.wait { $0 == .decided(url: foreign, isMainFrame: true, policy: .cancel) }
            fixture.proxy.webView(
                fixture.webView,
                didFailProvisionalNavigation: nil,
                withError: NSError(domain: "WebKitErrorDomain", code: 102)
            )
            _ = try await fixture.evaluate("true")
            try await fixture.proxy.sendMessage(ProbeMessage(type: "native.afterBlock"))

            let received = try await fixture.evaluate("window.received.type") as? String
            #expect(received == "native.afterBlock")
        }

        @Test func allowsAMainFrameNavigationWithinTheSignerOrigin() async throws {
            let fixture = SignerPageFixture()
            try await fixture.proxy.loadURL(fixture.url(SignerPageFixture.SIGNER_URL))
            let second = try fixture.url(SignerPageFixture.SIGNER_SECOND_PAGE_URL)

            fixture.webView.load(URLRequest(url: second))
            await fixture.navigations.wait { $0 == .finished(second) }

            #expect(fixture.navigations.events.contains(.decided(url: second, isMainFrame: true, policy: .allow)))
        }

        @Test func allowsSubframeNavigationsOffTheSignerOrigin() async throws {
            let fixture = SignerPageFixture()
            try await fixture.proxy.loadURL(fixture.url(SignerPageFixture.SIGNER_FRAMES_URL))

            await fixture.navigations.wait {
                guard case .decided(let url, false, _) = $0 else { return false }
                return url?.scheme == "data"
            }

            let subframeDecisions = fixture.navigations.events.filter {
                guard case .decided(let url, false, _) = $0 else { return false }
                return url?.scheme == "data"
            }
            #expect(subframeDecisions.allSatisfy {
                guard case .decided(_, _, let policy) = $0 else { return false }
                return policy == .allow
            })
        }

        @Test func failsTheInitialLoadOfANonHttpsSigner() async throws {
            let fixture = SignerPageFixture()
            let insecure = try fixture.url(SignerPageFixture.INSECURE_SIGNER_URL)

            await #expect(throws: WebViewError.navigationFailed(URLError(.cancelled))) {
                try await fixture.proxy.loadURL(insecure)
            }
            #expect(fixture.navigations.events.contains(.decided(url: insecure, isMainFrame: true, policy: .cancel)))
        }
    }

    @Suite("Receiving messages")
    @MainActor
    struct ReceivingTests {
        @Test func deliversMainFrameMessagesFromTheSignerOrigin() async throws {
            let fixture = SignerPageFixture()
            try await fixture.proxy.loadURL(fixture.url(SignerPageFixture.SIGNER_URL))

            await fixture.messages.wait(for: "signer.loaded")

            #expect(fixture.messages.types == ["signer.loaded"])
        }

        @Test func dropsMessagesFromASubframeOnTheSignerOrigin() async throws {
            let fixture = SignerPageFixture()
            try await fixture.proxy.loadURL(fixture.url(SignerPageFixture.SIGNER_FRAMES_URL))

            await fixture.messages.wait(for: "signer.afterSubframe")

            #expect(fixture.messages.types == ["signer.afterSubframe"])
        }

        @Test func dropsMessagesFromAPageOffTheSignerOrigin() async throws {
            let fixture = SignerPageFixture()
            try await fixture.proxy.loadURL(fixture.url(SignerPageFixture.SIGNER_URL))
            await fixture.messages.wait(for: "signer.loaded")

            try await fixture.showWithoutProxy(SignerPageFixture.FOREIGN_URL)
            await fixture.messages.wait(for: "foreign.done")
            try fixture.webView.load(URLRequest(url: fixture.url(SignerPageFixture.SIGNER_SECOND_PAGE_URL)))
            await fixture.messages.wait(for: "signer.second")

            #expect(fixture.messages.types == ["signer.loaded", "foreign.done", "signer.second"])
        }
    }

    @Suite("JavaScript bridge")
    @MainActor
    struct BridgeTests {
        @Test func attachesOnlyOnTheSignerOrigin() async throws {
            let signer = try #require(SignerOrigin(url: URL(string: SignerPageFixture.SIGNER_URL)))
            let fixture = SignerPageFixture(bridgeOrigin: signer)
            try await fixture.proxy.loadURL(fixture.url(SignerPageFixture.SIGNER_URL))
            let onSigner = try await fixture.evaluate("typeof window.ReactNativeWebView") as? String

            try await fixture.showWithoutProxy(SignerPageFixture.FOREIGN_URL)
            let offSigner = try await fixture.evaluate("typeof window.ReactNativeWebView") as? String

            #expect(onSigner == "object")
            #expect(offSigner == "undefined")
        }
    }
}
