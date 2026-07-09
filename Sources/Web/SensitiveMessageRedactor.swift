import Foundation

enum SensitiveMessageRedactor {
    private static let sensitiveKeys: Set<String> = ["jwt", "apiKey", "encryptedOtp"]
    private static let redactedPlaceholder = "[REDACTED]"

    static func redactedLoggableString(from data: Data) -> String {
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) else {
            return "<unparseable message>"
        }

        let redacted = redact(jsonObject)
        guard let redactedData = try? JSONSerialization.data(withJSONObject: redacted, options: []),
              let string = String(data: redactedData, encoding: .utf8) else {
            return "<redaction failed>"
        }
        return string
    }

    private static func redact(_ value: Any) -> Any {
        guard let dictionary = value as? [String: Any] else {
            return value
        }

        var result: [String: Any] = [:]
        for (key, nestedValue) in dictionary {
            result[key] = sensitiveKeys.contains(key) ? redactedPlaceholder : redact(nestedValue)
        }
        return result
    }
}
