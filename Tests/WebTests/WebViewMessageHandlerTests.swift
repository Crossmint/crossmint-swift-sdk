import Foundation
import Testing
@testable import Web
@testable import Logger

@Suite("WebViewMessageHandler Tests")
@MainActor
// swiftlint:disable:next type_body_length
struct WebViewMessageHandlerTests {
    final class MockWebViewMessageHandlerDelegate: WebViewMessageHandlerDelegate {
        var receivedMessages: [any WebViewMessage] = []
        var receivedUnknownMessages: [(type: String, data: Data)] = []

        func handleWebViewMessage<T: WebViewMessage>(_ message: T) {
            receivedMessages.append(message)
        }

        func handleUnknownMessage(_ messageType: String, data: Data) {
            receivedUnknownMessages.append((type: messageType, data: data))
        }
    }

    @Test("Process console.log message with data array")
    func testProcessConsoleLogMessage() throws {
        let handler = WebViewMessageHandler()
        let delegate = MockWebViewMessageHandlerDelegate()
        handler.setDelegate(delegate)

        let messageJson = """
        {"type":"console.log","data":["Function [IndexedDB service init] took 68ms to execute"]}
        """

        handler.processIncomingMessage(messageJson)

        #expect(delegate.receivedMessages.isEmpty)
        #expect(delegate.receivedUnknownMessages.isEmpty)
    }

    @Test("Process console.warn message")
    func testProcessConsoleWarnMessage() throws {
        let handler = WebViewMessageHandler()
        let delegate = MockWebViewMessageHandlerDelegate()
        handler.setDelegate(delegate)

        let messageJson = """
        {"type":"console.warn","data":["using deprecated parameters for the initialization function"]}
        """

        handler.processIncomingMessage(messageJson)

        #expect(delegate.receivedMessages.isEmpty)
        #expect(delegate.receivedUnknownMessages.isEmpty)
    }

    @Test("Process console messages with different severities")
    func testProcessConsoleMessagesWithDifferentSeverities() throws {
        let handler = WebViewMessageHandler()
        let delegate = MockWebViewMessageHandlerDelegate()
        handler.setDelegate(delegate)

        let severities = ["log", "warn", "error", "debug", "info", "trace"]

        for severity in severities {
            let messageJson = """
            {"type":"console.\(severity)","data":["Test message for \(severity)"]}
            """

            handler.processIncomingMessage(messageJson)
        }

        #expect(delegate.receivedMessages.isEmpty)
        #expect(delegate.receivedUnknownMessages.isEmpty)
    }

    @Test("Process console message with multiple data elements")
    func testProcessConsoleMessageWithMultipleDataElements() throws {
        let handler = WebViewMessageHandler()
        let delegate = MockWebViewMessageHandlerDelegate()
        handler.setDelegate(delegate)

        let messageJson = """
        {"type":"console.log","data":["-- Initializing", "Events", "Service"]}
        """

        handler.processIncomingMessage(messageJson)

        #expect(delegate.receivedMessages.isEmpty)
        #expect(delegate.receivedUnknownMessages.isEmpty)
    }

    @Test("Process handshake response message")
    func testProcessHandshakeResponseMessage() throws {
        let handler = WebViewMessageHandler()
        let delegate = MockWebViewMessageHandlerDelegate()
        handler.setDelegate(delegate)

        let messageJson = """
        {"event":"handshakeResponse","data":{"requestVerificationId":"PnsxYXthD9"}}
        """

        handler.processIncomingMessage(messageJson)

        #expect(delegate.receivedMessages.count == 1)
        #expect(delegate.receivedMessages.first is HandshakeResponse)

        if let handshakeResponse = delegate.receivedMessages.first as? HandshakeResponse {
            #expect(handshakeResponse.data.requestVerificationId == "PnsxYXthD9")
        }
    }

    @Test("Process handshake complete message")
    func testProcessHandshakeCompleteMessage() throws {
        let handler = WebViewMessageHandler()
        let delegate = MockWebViewMessageHandlerDelegate()
        handler.setDelegate(delegate)

        let messageJson = """
        {"event":"handshakeComplete","data":{"requestVerificationId":"COMPLETE123"}}
        """

        handler.processIncomingMessage(messageJson)

        #expect(delegate.receivedMessages.count == 1)
        #expect(delegate.receivedMessages.first is HandshakeComplete)

        if let handshakeComplete = delegate.receivedMessages.first as? HandshakeComplete {
            #expect(handshakeComplete.data.requestVerificationId == "COMPLETE123")
        }
    }

    @Test("Process handshake request message")
    func testProcessHandshakeRequestMessage() throws {
        let handler = WebViewMessageHandler()
        let delegate = MockWebViewMessageHandlerDelegate()
        handler.setDelegate(delegate)

        let messageJson = """
        {"event":"handshakeRequest","data":{"requestVerificationId":"ABC123"}}
        """

        handler.processIncomingMessage(messageJson)

        #expect(delegate.receivedMessages.count == 1)
        #expect(delegate.receivedMessages.first is HandshakeRequest)

        if let handshakeRequest = delegate.receivedMessages.first as? HandshakeRequest {
            #expect(handshakeRequest.data.requestVerificationId == "ABC123")
        }
    }

    @Test("Process unknown message type logs warning")
    func testProcessUnknownMessageType() throws {
        let handler = WebViewMessageHandler()
        let delegate = MockWebViewMessageHandlerDelegate()
        handler.setDelegate(delegate)

        let messageJson = """
        {"type":"unknown.message","data":{"some":"data"}}
        """

        // Process the message - it should log a warning
        handler.processIncomingMessage(messageJson)

        #expect(delegate.receivedMessages.isEmpty)
        #expect(delegate.receivedUnknownMessages.count == 1)
        #expect(delegate.receivedUnknownMessages.first?.type == "unknown.message")

        // Verify the data was passed to the delegate
        if let unknownMessage = delegate.receivedUnknownMessages.first {
            let jsonString = String(data: unknownMessage.data, encoding: .utf8)
            #expect(jsonString == messageJson)
        }
    }

    @Test("Process invalid JSON message")
    func testProcessInvalidJsonMessage() throws {
        let handler = WebViewMessageHandler()
        let delegate = MockWebViewMessageHandlerDelegate()
        handler.setDelegate(delegate)

        let invalidJson = "not a json"

        handler.processIncomingMessage(invalidJson)

        #expect(delegate.receivedMessages.isEmpty)
        #expect(delegate.receivedUnknownMessages.isEmpty)
    }

    @Test("Process message without type or event")
    func testProcessMessageWithoutTypeOrEvent() throws {
        let handler = WebViewMessageHandler()
        let delegate = MockWebViewMessageHandlerDelegate()
        handler.setDelegate(delegate)

        let messageJson = """
        {"data":{"some":"data"}}
        """

        handler.processIncomingMessage(messageJson)

        #expect(delegate.receivedMessages.isEmpty)
        #expect(delegate.receivedUnknownMessages.isEmpty)
    }

    @Test("Queue messages when not ready")
    func testQueueMessagesWhenNotReady() throws {
        let handler = WebViewMessageHandler()
        handler.setReady(false)

        let messageData = Data("test message".utf8)

        let queued = handler.queueMessage(messageData)

        #expect(queued == true)

        let pendingMessages = handler.getPendingMessages()
        #expect(pendingMessages.count == 1)
        #expect(pendingMessages.first == messageData)
    }

    @Test("Don't queue messages when ready")
    func testDontQueueMessagesWhenReady() throws {
        let handler = WebViewMessageHandler()
        handler.setReady(true)

        let messageData = Data("test message".utf8)

        let queued = handler.queueMessage(messageData)

        #expect(queued == false)

        let pendingMessages = handler.getPendingMessages()
        #expect(pendingMessages.isEmpty)
    }

    @Test("Clear pending messages when setting ready to false")
    func testClearPendingMessagesWhenSettingReadyToFalse() throws {
        let handler = WebViewMessageHandler()
        handler.setReady(false)

        let messageData = Data("test message".utf8)
        _ = handler.queueMessage(messageData)

        handler.setReady(false)

        let pendingMessages = handler.getPendingMessages()
        #expect(pendingMessages.isEmpty)
    }

    @Test("Wait for specific message type")
    func testWaitForSpecificMessageType() async throws {
        let handler = WebViewMessageHandler()

        let expectation = Task {
            try await handler.waitForMessage(
                ofType: HandshakeResponse.self,
                timeout: 1.0
            )
        }

        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        let messageJson = """
        {"event":"handshakeResponse","data":{"requestVerificationId":"XYZ789"}}
        """

        handler.processIncomingMessage(messageJson)

        let result = try await expectation.value
        #expect(result.data.requestVerificationId == "XYZ789")
    }

    @Test("Wait for HandshakeComplete message type")
    func testWaitForHandshakeCompleteMessageType() async throws {
        let handler = WebViewMessageHandler()

        let expectation = Task {
            try await handler.waitForMessage(
                ofType: HandshakeComplete.self,
                timeout: 1.0
            )
        }

        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        let messageJson = """
        {"event":"handshakeComplete","data":{"requestVerificationId":"WAIT123"}}
        """

        handler.processIncomingMessage(messageJson)

        let result = try await expectation.value
        #expect(result.data.requestVerificationId == "WAIT123")
    }

    @Test("Wait for message with predicate")
    func testWaitForMessageWithPredicate() async throws {
        let handler = WebViewMessageHandler()

        let expectation = Task {
            try await handler.waitForMessage(
                ofType: HandshakeResponse.self,
                matching: { $0.data.requestVerificationId == "MATCH123" },
                timeout: 1.0
            )
        }

        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Send non-matching message
        let nonMatchingJson = """
        {"event":"handshakeResponse","data":{"requestVerificationId":"NOMATCH"}}
        """
        handler.processIncomingMessage(nonMatchingJson)

        // Send matching message
        let matchingJson = """
        {"event":"handshakeResponse","data":{"requestVerificationId":"MATCH123"}}
        """
        handler.processIncomingMessage(matchingJson)

        let result = try await expectation.value
        #expect(result.data.requestVerificationId == "MATCH123")
    }

    @Test("Wait for message timeout")
    func testWaitForMessageTimeout() async throws {
        let handler = WebViewMessageHandler()

        await #expect(throws: WebViewError.timeout) {
            try await handler.waitForMessage(
                ofType: HandshakeResponse.self,
                timeout: 0.1
            )
        }
    }

    @Test("Reset handler clears state")
    func testResetHandlerClearsState() async throws {
        let handler = WebViewMessageHandler()
        handler.setReady(true)

        handler.setReady(false)
        let messageData = Data("test message".utf8)
        _ = handler.queueMessage(messageData)

        let expectation = Task {
            try await handler.waitForMessage(
                ofType: HandshakeResponse.self,
                timeout: 5.0
            )
        }

        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        handler.reset()

        await #expect(throws: WebViewError.webViewNotAvailable) {
            try await expectation.value
        }

        let pendingMessages = handler.getPendingMessages()
        #expect(pendingMessages.isEmpty)
    }

    @Test("Extract message data from string body")
    func testExtractMessageDataFromString() throws {
        let handler = WebViewMessageHandler()
        let delegate = MockWebViewMessageHandlerDelegate()
        handler.setDelegate(delegate)

        let messageString = """
        {"type":"console.log","data":["Test from string"]}
        """

        handler.processIncomingMessage(messageString)

        #expect(delegate.receivedUnknownMessages.isEmpty)
    }

    @Test("Extract message data from dictionary body")
    func testExtractMessageDataFromDictionary() throws {
        let handler = WebViewMessageHandler()
        let delegate = MockWebViewMessageHandlerDelegate()
        handler.setDelegate(delegate)

        let messageDict: [String: Any] = [
            "event": "handshakeResponse",
            "data": ["requestVerificationId": "DICT123"]
        ]

        handler.processIncomingMessage(messageDict)

        #expect(delegate.receivedMessages.count == 1)
        #expect(delegate.receivedMessages.first is HandshakeResponse)
    }

    // MARK: - Message Buffer Tests

    @Test("Message buffer stores messages")
    func testMessageBufferStoresMessages() throws {
        let handler = WebViewMessageHandler()
        let delegate = MockWebViewMessageHandlerDelegate()
        handler.setDelegate(delegate)

        let messageJson = """
        {"event":"handshakeResponse","data":{"requestVerificationId":"BUFFER123"}}
        """

        handler.processIncomingMessage(messageJson)

        // The message should be delivered to delegate and stored in buffer
        #expect(delegate.receivedMessages.count == 1)
    }

    @Test("Wait for message checks buffer first")
    func testWaitForMessageChecksBufferFirst() async throws {
        let handler = WebViewMessageHandler()

        // Process a message first (it will be buffered)
        let messageJson = """
        {"event":"handshakeResponse","data":{"requestVerificationId":"PREBUFFER123"}}
        """
        handler.processIncomingMessage(messageJson)

        // Now wait for it - should return immediately from buffer
        let result = try await handler.waitForMessage(
            ofType: HandshakeResponse.self,
            timeout: 5.0
        )

        #expect(result.data.requestVerificationId == "PREBUFFER123")
    }

    @Test("Wait for message with predicate checks buffer")
    func testWaitForMessageWithPredicateChecksBuffer() async throws {
        let handler = WebViewMessageHandler()

        // Process multiple messages
        let messages = [
            """
            {"event":"handshakeResponse","data":{"requestVerificationId":"FIRST"}}
            """,
            """
            {"event":"handshakeResponse","data":{"requestVerificationId":"SECOND"}}
            """,
            """
            {"event":"handshakeResponse","data":{"requestVerificationId":"THIRD"}}
            """
        ]

        for message in messages {
            handler.processIncomingMessage(message)
        }

        // Wait for specific message
        let result = try await handler.waitForMessage(
            ofType: HandshakeResponse.self,
            matching: { $0.data.requestVerificationId == "SECOND" },
            timeout: 5.0
        )

        #expect(result.data.requestVerificationId == "SECOND")
    }

    @Test("Message removed from buffer when consumed")
    func testMessageRemovedFromBufferWhenConsumed() async throws {
        let handler = WebViewMessageHandler()

        let messageJson = """
        {"event":"handshakeResponse","data":{"requestVerificationId":"CONSUME123"}}
        """
        handler.processIncomingMessage(messageJson)

        // First wait should succeed
        let result = try await handler.waitForMessage(
            ofType: HandshakeResponse.self,
            matching: { $0.data.requestVerificationId == "CONSUME123" },
            timeout: 1.0
        )
        #expect(result.data.requestVerificationId == "CONSUME123")

        // Second wait should timeout since message was consumed
        await #expect(throws: WebViewError.timeout) {
            try await handler.waitForMessage(
                ofType: HandshakeResponse.self,
                matching: { $0.data.requestVerificationId == "CONSUME123" },
                timeout: 0.1
            )
        }
    }

    @Test("New pattern: send message then wait")
    func testNewPatternSendThenWait() async throws {
        let handler = WebViewMessageHandler()

        // Simulate the new pattern where message arrives before we wait
        let responseArrival = Task {
            try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
            let messageJson = """
            {"event":"handshakeResponse","data":{"requestVerificationId":"PATTERN123"}}
            """
            handler.processIncomingMessage(messageJson)
        }

        // Wait a bit to ensure message arrives first
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Now wait for the message - should find it in buffer
        let result = try await handler.waitForMessage(
            ofType: HandshakeResponse.self,
            timeout: 1.0
        )

        #expect(result.data.requestVerificationId == "PATTERN123")
        try await responseArrival.value
    }
}
