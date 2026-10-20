import Foundation
import Testing
import WebKit
@testable import CrossmintClient

@Suite("Offramp WebView transport")
@MainActor
struct EmbeddedOfframpWebViewTests {
    @Test func exchangesMessagesThroughTheActualPageChannel() async throws {
        let config = WKWebViewConfiguration()
        let receiver = MessageReceiver()
        config.userContentController.add(receiver, name: "crossmintOfframp")
        config.userContentController.addUserScript(WKUserScript(
            source: OfframpWebView.script, injectionTime: .atDocumentStart, forMainFrameOnly: true
        ))
        let view = WKWebView(frame: .zero, configuration: config)
        let ready = await withCheckedContinuation { continuation in
            receiver.receive = { continuation.resume(returning: $0) }
            view.loadHTMLString(
                "<script>window.ReactNativeWebView.postMessage('ready');</script>", baseURL: nil
            )
        }
        let envelope = try JSONDecoder().decode(PageMessage.self, from: Data(ready.utf8))
        #expect(envelope.message == "ready")
        let payload = #"{"event":"crypto:send-transaction:success","data":{"txId":"quote'\n</script>"}}"#
        _ = try await view.evaluateJavaScript(
            "window.received = []; window.addEventListener('message', event => window.received.push(event.data));"
        )
        for documentId in ["old-document", envelope.documentId] {
            _ = try await view.callAsyncJavaScript(
                OfframpWebView.replyScript,
                arguments: ["message": payload, "documentId": documentId], in: nil, contentWorld: .page
            )
        }
        let result = try await view.evaluateJavaScript("JSON.stringify(window.received)")
        let text = try #require(result as? String)
        let replies = try JSONDecoder().decode([Response].self, from: Data(text.utf8))
        #expect(replies.count == 1)
        #expect(replies.first?.data.txId == "quote'\n</script>")
        config.userContentController.removeScriptMessageHandler(forName: "crossmintOfframp")
    }

    private struct PageMessage: Decodable {
        let documentId: String
        let message: String
    }

    private struct Response: Decodable {
        let data: TransactionID
        struct TransactionID: Decodable { let txId: String }
    }

    private final class MessageReceiver: NSObject, WKScriptMessageHandler {
        var receive: ((String) -> Void)?

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            if let text = message.body as? String { receive?(text) }
        }
    }
}
