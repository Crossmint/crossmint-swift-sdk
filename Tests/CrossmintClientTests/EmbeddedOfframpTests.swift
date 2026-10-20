import Foundation
import Testing
@testable import CrossmintClient

@Suite("Embedded offramp")
@MainActor
struct EmbeddedOfframpTests {
    @Test func encodesCredentialsWithoutLosingReservedCharacters() throws {
        let config = try EmbeddedOfframpConfiguration(
            apiKey: "ck_staging_test",
            credentials: .init(sessionId: "session&=+", clientSecret: "secret/#?"),
            locale: "es"
        )
        let parts = try #require(URLComponents(url: config.url, resolvingAgainstBaseURL: false))
        #expect(parts.host == "staging.crossmint.com")
        #expect(parts.path == "/sdk/unstable/embedded-offramp")
        let raw = try #require(parts.queryItems?.first { $0.name == "credentials" }?.value)
        let credentials = try JSONDecoder().decode(EmbeddedOfframpCredentials.self, from: Data(raw.utf8))
        #expect(credentials.sessionId == "session&=+")
        #expect(credentials.clientSecret == "secret/#?")
        #expect(parts.queryItems?.contains { $0.name == "payer" } == false)
    }

    @Test func refusesServerKeysAndEmptyCredentials() {
        #expect(throws: (any Error).self) {
            try EmbeddedOfframpConfiguration(
                apiKey: "sk_staging_test", credentials: .init(sessionId: "s", clientSecret: "secret")
            )
        }
        #expect(throws: (any Error).self) {
            try EmbeddedOfframpConfiguration(
                apiKey: "ck_staging_test", credentials: .init(sessionId: "", clientSecret: "secret")
            )
        }
    }

    @Test func rejectsForeignAndSubframeSigningMessages() async throws {
        let config = try EmbeddedOfframpConfiguration(
            apiKey: "ck_staging_test", credentials: .init(sessionId: "s", clientSecret: "secret")
        )
        var calls = 0
        let bridge = EmbeddedOfframpBridge(configuration: config, payer: { _ in
            calls += 1
            return "hash"
        })
        let message = #"""
        {"event":"crypto:send-transaction","data":
        {"chain":"solana","payerAddress":"payer","serializedTransaction":"encoded"}}
        """#
        await bridge.receive(message, source: URL(string: "https://evil.example"), mainFrame: true)
        await bridge.receive(message, source: config.url, mainFrame: false)
        #expect(calls == 0)
    }

    @Test func distinguishesRejectionFromUnknownBroadcastOutcome() async throws {
        let config = try EmbeddedOfframpConfiguration(
            apiKey: "ck_staging_test", credentials: .init(sessionId: "s", clientSecret: "secret")
        )
        let message = #"""
        {"event":"crypto:send-transaction","data":
        {"chain":"solana","payerAddress":"payer","serializedTransaction":"encoded"}}
        """#
        for rejected in [false, true] {
            var reply: String?
            let bridge = EmbeddedOfframpBridge(configuration: config, payer: { _ in
                if rejected { throw OfframpSignatureRejected() }
                throw URLError(.timedOut)
            })
            bridge.reply = { reply = $0 }
            await bridge.receive(message, source: config.url, mainFrame: true)
            let result = try JSONDecoder().decode(Reply.self, from: Data(try #require(reply).utf8))
            #expect(result.event == "crypto:send-transaction:failed")
            #expect(result.data.rejected == rejected)
        }
    }

    @Test func sendsOnceForRepeatedRequestAndSafelyEncodesReply() async throws {
        let config = try EmbeddedOfframpConfiguration(
            apiKey: "ck_production_test", credentials: .init(sessionId: "s", clientSecret: "secret")
        )
        #expect(config.url.host == "www.crossmint.com")
        var calls = 0
        var replies: [String] = []
        let bridge = EmbeddedOfframpBridge(configuration: config, payer: { _ in
            calls += 1
            return "hash'\\\n</script>"
        })
        bridge.reply = { replies.append($0) }
        let message = #"""
        {"event":"crypto:send-transaction","data":
        {"chain":"base","payerAddress":"payer","serializedTransaction":"0xencoded"}}
        """#
        await bridge.receive(message, source: config.url, mainFrame: true)
        await bridge.receive(message, source: config.url, mainFrame: true)
        #expect(calls == 1)
        #expect(replies.count == 2)
        let response = try JSONDecoder().decode(SuccessReply.self, from: Data(try #require(replies.first).utf8))
        #expect(response.data.txId == "hash'\\\n</script>")
        #expect(response.event == "crypto:send-transaction:success")
    }

    @Test func ignoresMalformedPayloadAndMessagesAfterRemoval() async throws {
        let config = try EmbeddedOfframpConfiguration(
            apiKey: "ck_staging_test", credentials: .init(sessionId: "s", clientSecret: "secret")
        )
        var calls = 0
        let bridge = EmbeddedOfframpBridge(configuration: config, payer: { _ in
            calls += 1
            return "hash"
        })
        await bridge.receive(#"""
        {"event":"crypto:send-transaction","data":
        {"chain":1}}
        """#,
                             source: config.url, mainFrame: true)
        bridge.active = false
        await bridge.receive(
            #"""
        {"event":"crypto:send-transaction","data":
        {"chain":"solana","payerAddress":"payer","serializedTransaction":"encoded"}}
        """#,
            source: config.url, mainFrame: true
        )
        #expect(calls == 0)
    }

    @Test func suppressesOldDocumentReplyButKeepsLateCurrentReply() async throws {
        for navigated in [false, true] {
            let config = try EmbeddedOfframpConfiguration(
                apiKey: "ck_staging_test", credentials: .init(sessionId: "s", clientSecret: "secret")
            )
            var resume: CheckedContinuation<String, Never>?
            var replies: [String] = []
            let bridge = EmbeddedOfframpBridge(configuration: config, payer: { _ in
                await withCheckedContinuation { resume = $0 }
            })
            bridge.reply = { replies.append($0) }
            let pending = Task {
                await bridge.receive(
                    #"""
        {"event":"crypto:send-transaction","data":
        {"chain":"solana","payerAddress":"payer","serializedTransaction":"encoded"}}
        """#,
                    source: config.url, mainFrame: true
                )
            }
            while resume == nil { await Task.yield() }
            if navigated {
                bridge.beginNavigation()
                bridge.receiving = true
            }
            resume?.resume(returning: "late-hash")
            await pending.value
            #expect(replies.count == (navigated ? 0 : 1))
        }
    }

    @Test func reportsLifecycleEventsAndIgnoresInvalidStatusAndHeight() async throws {
        let config = try EmbeddedOfframpConfiguration(
            apiKey: "ck_staging_test", credentials: .init(sessionId: "s", clientSecret: "secret")
        )
        var events: [String] = []
        let bridge = EmbeddedOfframpBridge(
            configuration: config, payer: { _ in "hash" },
            callbacks: .init(
                onReady: { events.append("ready") },
                onStatusChange: { events.append($0.status.rawValue) },
                onComplete: { events.append($0.orderId) },
                onCancel: { events.append("cancel") },
                onError: { events.append($0.reason) },
                onHeightChange: { events.append(String($0)) }
            )
        )
        for message in [
            #"{"event":"offramp:ready","data":{}}"#,
            #"{"event":"offramp:status","data":{"status":"verifying-identity"}}"#,
            #"{"event":"offramp:status","data":{"status":"not-a-status"}}"#,
            #"{"event":"offramp:completed","data":{"orderId":"order-1","txId":"tx"}}"#,
            #"{"event":"offramp:cancelled","data":{}}"#,
            #"{"event":"offramp:error","data":{"reason":"provider-error","retriable":true,"message":"try again"}}"#,
            #"{"event":"ui:height.changed","data":{"height":-1}}"#,
            #"{"event":"ui:height.changed","data":{"height":640}}"#
        ] {
            await bridge.receive(message, source: config.url, mainFrame: true)
        }
        #expect(events == ["ready", "verifying-identity", "order-1", "cancel", "provider-error", "640.0"])
    }

    private struct SuccessReply: Decodable {
        let event: String
        let data: Success
        struct Success: Decodable { let txId: String }
    }

    private struct Reply: Decodable {
        let event: String
        let data: Failure
        struct Failure: Decodable { let rejected: Bool }
    }
}
