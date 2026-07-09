import Foundation

// TEE bridge messages carry `authData.jwt`, `authData.apiKey`, and `onboardingAuthentication.encryptedOtp`
// at varying nesting depths across message types, so redaction walks the decoded JSON by key rather than by path.
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
        if let dictionary = value as? [String: Any] {
            var result: [String: Any] = [:]
            for (key, nestedValue) in dictionary {
                result[key] = sensitiveKeys.contains(key) ? redactedPlaceholder : redact(nestedValue)
            }
            return result
        }

        if let array = value as? [Any] {
            return array.map(redact)
        }

        return value
    }
}
