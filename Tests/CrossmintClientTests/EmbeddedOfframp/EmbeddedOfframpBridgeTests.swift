import Foundation
import SwiftUI
import Testing
import WebKit
@testable import CrossmintClient

@Suite("Embedded offramp bridge", .tags(.unit))
@MainActor
struct EmbeddedOfframpBridgeTests {
    nonisolated static let TX_OUTCOMES: [(PayerOutcome, Reply)] = [
        (.returns("0xhash"), Reply(event: "crypto:send-transaction:success", data: .init(txId: "0xhash"))),
        (.returns(""), failed("crypto:send-transaction", "The wallet returned no transaction id", rejected: false)),
        (.fails(OfframpSignatureRejectedError(message: "no")), failed("crypto:send-transaction", "no", rejected: true)),
        (.fails(WalletFailure(errorDescription: "lost")), failed("crypto:send-transaction", "lost", rejected: false))
    ]

    nonisolated static let MESSAGE_OUTCOMES: [(PayerOutcome, Reply)] = [
        (.returns("0xsig"), Reply(event: "crypto:sign-message:success", data: .init(signature: "0xsig"))),
        (.returns(""), failed("crypto:sign-message", "The wallet returned no signature", rejected: false)),
        (.fails(OfframpSignatureRejectedError(message: "no")), failed("crypto:sign-message", "no", rejected: true)),
        (.fails(WalletFailure(errorDescription: "locked")), failed("crypto:sign-message", "locked", rejected: false))
    ]

    @Test(arguments: EmbeddedOfframpBridgeTests.TX_OUTCOMES)
    func repliesToADepositWithThePayerOutcome(outcome: PayerOutcome, expected: Reply) async throws {
        let bridge = try makeBridge(for: makeOfframp(payer: EmbeddedOfframpPayer(signAndSendTransaction: { _ in
            try outcome.value()
        })))

        #expect(try await reply(of: bridge, to: try makeSendTransactionRequest()) == [expected])
    }

    @Test(arguments: EmbeddedOfframpBridgeTests.MESSAGE_OUTCOMES)
    func repliesToAnOwnershipProofWithThePayerOutcome(outcome: PayerOutcome, expected: Reply) async throws {
        let bridge = try makeBridge(for: makeOfframp(payer: EmbeddedOfframpPayer(
            signAndSendTransaction: { _ in "" },
            signMessage: { _ in try outcome.value() }
        )))

        #expect(try await reply(of: bridge, to: try makeSignMessageRequest()) == [expected])
    }

    @Test func refusesAnOwnershipProofWhenThePayerCannotSignMessages() async throws {
        let bridge = try makeBridge(for: makeOfframp())

        let replies = try await reply(of: bridge, to: try makeSignMessageRequest())

        #expect(replies == [Self.failed("crypto:sign-message", "This payer cannot sign messages", rejected: false)])
    }

    @Test func ignoresARequestThatArrivesWhileTheSameKindIsPending() async throws {
        var calls = 0
        var resume: CheckedContinuation<String, Never>?
        let bridge = try makeBridge(for: makeOfframp(payer: EmbeddedOfframpPayer(signAndSendTransaction: { _ in
            calls += 1
            if calls > 1 {
                return "0xsecond"
            }
            return await withCheckedContinuation { resume = $0 }
        })))
        var replies: [String] = []
        bridge.reply = { replies.append($0) }

        let first = bridge.receive(try makeSendTransactionRequest(), frameURL: bridge.host.page, mainFrame: true)
        while resume == nil { await Task.yield() }
        await bridge.receive(try makeSendTransactionRequest(), frameURL: bridge.host.page, mainFrame: true)?.value
        resume?.resume(returning: "0xhash")
        await first?.value

        #expect(calls == 1)
        #expect(replies.count == 1)
    }

    @Test func answersTheNextRequestAfterThePageMissesAReply() async throws {
        let bridge = try makeBridge(for: makeOfframp())
        var attempts = 0
        bridge.reply = { _ in
            attempts += 1
            if attempts == 1 { throw WKError(.webViewInvalidated) }
        }

        await bridge.receive(try makeSendTransactionRequest(), frameURL: bridge.host.page, mainFrame: true)?.value
        await bridge.receive(try makeSendTransactionRequest(), frameURL: bridge.host.page, mainFrame: true)?.value

        #expect(attempts == 2)
    }

    @Test func answersOnlyTheDocumentThatIsShownNow() async throws {
        var resumeOld: CheckedContinuation<String, Never>?
        let bridge = try makeBridge(for: makeOfframp(payer: EmbeddedOfframpPayer(signAndSendTransaction: { _ in
            if resumeOld == nil {
                return await withCheckedContinuation { resumeOld = $0 }
            }
            return "0xnew"
        })))
        var replies: [String] = []
        bridge.reply = { replies.append($0) }

        let old = bridge.receive(try makeSendTransactionRequest(), frameURL: bridge.host.page, mainFrame: true)
        while resumeOld == nil { await Task.yield() }
        bridge.forgetPendingRequests()
        await bridge.receive(try makeSendTransactionRequest(), frameURL: bridge.host.page, mainFrame: true)?.value
        resumeOld?.resume(returning: "0xold")
        await old?.value

        let decoded = try replies.map { try JSONDecoder().decode(Reply.self, from: Data($0.utf8)) }
        #expect(decoded == [Reply(event: "crypto:send-transaction:success", data: .init(txId: "0xnew"))])
    }

    @Test(arguments: [(false, true), (true, false)])
    func ignoresMessagesFromOtherPagesOrFrames(fromPage: Bool, mainFrame: Bool) async throws {
        var calls = 0
        var ready = false
        let view = makeOfframp(payer: EmbeddedOfframpPayer(signAndSendTransaction: { _ in
            calls += 1
            return "0xhash"
        })).onReady { ready = true }
        let bridge = try makeBridge(for: view)
        let frameURL = fromPage ? bridge.host.page : URL(string: "https://evil.example/sdk/unstable/embedded-offramp")

        bridge.receive(try makeMessage("offramp:ready", [:]), frameURL: frameURL, mainFrame: mainFrame)
        await bridge.receive(try makeSendTransactionRequest(), frameURL: frameURL, mainFrame: mainFrame)?.value

        #expect(calls == 0)
        #expect(!ready)
    }

    @Test(arguments: [("verifying-wallet", OfframpStatus.verifyingWallet), ("a-later-step", .unknown)])
    func reportsEveryStatusThePageSends(wire: String, expected: OfframpStatus) throws {
        var reported: [OfframpStatusChange] = []
        let bridge = try makeBridge(for: makeOfframp().onStatusChange { reported.append($0) })

        let status = try makeMessage("offramp:status", ["status": wire, "orderId": "o1"])

        bridge.receive(status, frameURL: bridge.host.page, mainFrame: true)

        #expect(reported.map(\.status) == [expected])
        #expect(reported.map(\.orderId) == ["o1"])
    }

    @Test func takesTheHeightThePageReports() throws {
        var height: CGFloat = 0
        let bridge = try makeBridge(for: makeOfframp(), height: Binding(get: { height }, set: { height = $0 }))

        let resize = #"{"event":"ui:height.changed","data":{"height":812.5}}"#

        bridge.receive(resize, frameURL: bridge.host.page, mainFrame: true)

        #expect(height == 812.5)
    }

    @Test(arguments: [0, -1])
    func ignoresAHeightOfZeroOrLess(reported: CGFloat) throws {
        let initial = CGFloat.random(in: 1...1000)
        var height = initial
        let bridge = try makeBridge(for: makeOfframp(), height: Binding(get: { height }, set: { height = $0 }))

        let resize = #"{"event":"ui:height.changed","data":{"height":\#(reported)}}"#

        bridge.receive(resize, frameURL: bridge.host.page, mainFrame: true)

        #expect(height == initial)
    }

    private func reply(of bridge: EmbeddedOfframpBridge, to request: String) async throws -> [Reply] {
        var replies: [String] = []
        bridge.reply = { replies.append($0) }
        await bridge.receive(request, frameURL: bridge.host.page, mainFrame: true)?.value
        return try replies.map { try JSONDecoder().decode(Reply.self, from: Data($0.utf8)) }
    }

    nonisolated private static func failed(_ request: String, _ error: String, rejected: Bool) -> Reply {
        Reply(event: "\(request):failed", data: .init(error: error, rejected: rejected))
    }

    @Suite("navigation")
    @MainActor
    struct NavigationTests {
        @Test(arguments: [("https://terms.example/x", true), ("javascript:alert(1)", false)])
        func opensWebLinksForANewWindowOutsideTheView(url: String, opens: Bool) throws {
            let bridge = try makeBridge(for: makeOfframp())
            var opened: [String] = []
            bridge.openExternally = { opened.append($0.absoluteString) }

            let policy = bridge.navigationPolicy(for: URL(string: url), targetIsMainFrame: nil, linkActivated: false)

            #expect(policy == .cancel)
            #expect(opened == (opens ? [url] : []))
        }

        @Test(arguments: [
            ("https://terms.example/x", true),
            ("mailto:help@terms.example", false),
            ("javascript:alert(1)", false)
        ])
        func opensWebLinksTheUserTapsOutsideTheView(url: String, opens: Bool) throws {
            let bridge = try makeBridge(for: makeOfframp())
            var opened: [String] = []
            bridge.openExternally = { opened.append($0.absoluteString) }

            let policy = bridge.navigationPolicy(for: URL(string: url), targetIsMainFrame: true, linkActivated: true)

            #expect(policy == .cancel)
            #expect(opened == (opens ? [url] : []))
        }

        @Test(arguments: [("https://withpersona.com/verify", true), ("javascript:alert(1)", false)])
        func allowsFramesInsideThePageExceptScripts(url: String, allowed: Bool) throws {
            let bridge = try makeBridge(for: makeOfframp())
            let policy = bridge.navigationPolicy(for: URL(string: url), targetIsMainFrame: false, linkActivated: false)

            #expect(policy == (allowed ? .allow : .cancel))
        }

        @Test func keepsTheMainFrameOnThePageWhateverItsQuery() throws {
            let bridge = try makeBridge(for: makeOfframp())
            var opened: [URL] = []
            bridge.openExternally = { opened.append($0) }
            let page = bridge.host.page
            var otherQuery = try #require(URLComponents(url: page, resolvingAgainstBaseURL: false))
            otherQuery.queryItems = [URLQueryItem(name: "step", value: UUID().uuidString)]
            var otherHost = try #require(URLComponents(url: page, resolvingAgainstBaseURL: false))
            otherHost.host = "evil.example"
            let policy = { bridge.navigationPolicy(for: $0, targetIsMainFrame: true, linkActivated: false) }

            #expect(policy(page) == .allow)
            #expect(policy(otherQuery.url) == .allow)
            #expect(policy(otherHost.url) == .cancel)
            #expect(opened.isEmpty)
        }
    }

    @Suite("load failures")
    @MainActor
    struct LoadFailureTests {
        @Test(arguments: [
            (404, OfframpError.Reason.invalidConfiguration, false),
            (503, .providerError, true)
        ])
        func reportsAnHttpFailureByWhetherARetryCanWork(
            status: Int, reason: OfframpError.Reason, retriable: Bool
        ) throws {
            var errors: [OfframpError] = []
            let bridge = try makeBridge(for: makeOfframp().onError { errors.append($0) })

            bridge.reportLoadFailure(status: status)

            #expect(errors.map(\.reason) == [reason])
            #expect(errors.map(\.retriable) == [retriable])
        }

        @Test func reportsAConnectionFailureAsRetriable() throws {
            var errors: [OfframpError] = []
            let bridge = try makeBridge(for: makeOfframp().onError { errors.append($0) })

            bridge.reportLoadFailure(URLError(.notConnectedToInternet))

            #expect(errors.map(\.reason) == [.providerError])
            #expect(errors.map(\.retriable) == [true])
        }

        @Test func reportsOnlyTheFirstFailureOfALoad() throws {
            var errors: [OfframpError] = []
            let bridge = try makeBridge(for: makeOfframp().onError { errors.append($0) })

            bridge.reportLoadFailure(status: 404)
            bridge.reportLoadFailure(NSError(domain: "WebKitErrorDomain", code: 102))

            #expect(errors.count == 1)
        }

        @Test func ignoresACancelledLoad() throws {
            var errors: [OfframpError] = []
            let bridge = try makeBridge(for: makeOfframp().onError { errors.append($0) })

            bridge.reportLoadFailure(URLError(.cancelled))

            #expect(errors.isEmpty)
        }
    }
}
