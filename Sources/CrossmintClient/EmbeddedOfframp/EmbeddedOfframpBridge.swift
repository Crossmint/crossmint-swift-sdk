import Foundation

@MainActor
final class EmbeddedOfframpBridge {
    let configuration: EmbeddedOfframpConfiguration
    var payer: @MainActor (OfframpTransaction) async throws -> String
    var callbacks: EmbeddedOfframpCallbacks
    var reply: ((String) -> Void)?
    var active = true
    var receiving = true
    private var document = 0
    private var signing = false
    private var replies: [OfframpTransaction: String] = [:]

    init(
        configuration: EmbeddedOfframpConfiguration,
        payer: @escaping @MainActor (OfframpTransaction) async throws -> String,
        callbacks: EmbeddedOfframpCallbacks = .init()
    ) {
        self.configuration = configuration
        self.payer = payer
        self.callbacks = callbacks
    }

    func beginNavigation() {
        document += 1
        receiving = false
    }

    // Each branch validates a distinct wire event before invoking its typed callback.
    // swiftlint:disable:next cyclomatic_complexity
    func receive(_ message: String, source: URL?, mainFrame: Bool) async {
        guard active, receiving, mainFrame, configuration.trusts(source),
              let data = message.data(using: .utf8),
              let name = try? JSONDecoder().decode(EventName.self, from: data) else { return }
        switch name.event {
        case "offramp:ready":
            if payload(Empty.self, data) != nil { callbacks.onReady() }
        case "offramp:cancelled":
            if payload(Empty.self, data) != nil { callbacks.onCancel() }
        case "offramp:status":
            if let status = payload(OfframpStatusChange.self, data) { callbacks.onStatusChange(status) }
        case "offramp:completed":
            if let completion = payload(OfframpCompletion.self, data) { callbacks.onComplete(completion) }
        case "offramp:error":
            if let error = payload(OfframpError.self, data) { callbacks.onError(error) }
        case "ui:height.changed":
            if let size = payload(Height.self, data), size.height.isFinite, size.height >= 0 {
                callbacks.onHeightChange(size.height)
            }
        case "crypto:send-transaction":
            if let transaction = payload(OfframpTransaction.self, data),
               !transaction.serializedTransaction.isEmpty, !transaction.chain.isEmpty,
               !transaction.payerAddress.isEmpty {
                await sign(transaction)
            }
        default:
            break
        }
    }

    private func payload<T: Decodable>(_ type: T.Type, _ data: Data) -> T? {
        try? JSONDecoder().decode(Incoming<T>.self, from: data).data
    }

    private func sign(_ transaction: OfframpTransaction) async {
        // The page has one outstanding request and no request ID. Never let another request consume its reply.
        guard !signing else { return }
        if let previous = replies[transaction] {
            reply?(previous)
            return
        }
        let originDocument = document
        signing = true
        defer { signing = false }
        let response: String?
        var cacheReply = true
        do {
            let txId = try await payer(transaction)
            guard !txId.isEmpty else {
                throw OfframpError(reason: "unknown", retriable: false,
                                   message: "The wallet returned an empty transaction ID")
            }
            response = encode("crypto:send-transaction:success", Success(txId: txId))
        } catch {
            cacheReply = !(error is OfframpSignatureRejected)
            response = encode("crypto:send-transaction:failed", Failure(
                error: error is OfframpSignatureRejected ? "The wallet rejected the transaction" : "The wallet failed",
                rejected: error is OfframpSignatureRejected
            ))
        }
        if let response {
            if cacheReply { replies[transaction] = response }
            // Do not time out a wallet: a late successful broadcast must still reach the page.
            if active, receiving, document == originDocument { reply?(response) }
        }
    }

    private func encode<T: Encodable>(_ event: String, _ data: T) -> String? {
        guard let encoded = try? JSONEncoder().encode(Outgoing(event: event, data: data)) else { return nil }
        return String(data: encoded, encoding: .utf8)
    }

    private struct EventName: Decodable { let event: String }
    private struct Incoming<T: Decodable>: Decodable { let data: T }
    private struct Outgoing<T: Encodable>: Encodable { let event: String; let data: T }
    private struct Empty: Decodable {}
    private struct Height: Decodable { let height: Double }
    private struct Success: Encodable { let txId: String }
    private struct Failure: Encodable { let error: String; let rejected: Bool }
}
