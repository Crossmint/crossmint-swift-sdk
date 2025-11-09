struct ConsoleLogMessage: WebViewMessage, Encodable {
    enum Severity: String, Codable {
        case log
        case warn
        case error
        case debug
        case info
        case trace

        var messageType: String {
            "console.\(rawValue)"
        }
    }

    static let messageType = "console.log"

    let type: String
    let message: String
    let severity: Severity

    init(message: String, severity: Severity = .log) {
        self.severity = severity
        self.type = severity.messageType
        self.message = message
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(String.self, forKey: .type)

        // Handle both 'message' (string) and 'data' (array) formats
        if let message = try? container.decode(String.self, forKey: .message) {
            self.message = message
        } else if let dataArray = try? container.decode([String].self, forKey: .data) {
            self.message = dataArray.joined(separator: " ")
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected either 'message' or 'data' field"
                )
            )
        }

        if let severity = type.split(separator: ".").last.map(String.init),
           let severityEnum = Severity(rawValue: severity) {
            self.severity = severityEnum
        } else {
            self.severity = .log
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode([message], forKey: .data)
    }

    enum CodingKeys: String, CodingKey {
        case type
        case message
        case data
    }
}
