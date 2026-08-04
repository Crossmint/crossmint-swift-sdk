import Foundation

/// Strips credentials out of log messages before any provider sees them, including the remote ones
/// that ship logs off device. OSLog privacy specifiers can't cover this: they redact only inside the
/// system log store, and never reach a provider holding the message as a plain `String`.
enum CredentialScrubber {
    private static let patterns: [(regex: NSRegularExpression, replacement: String)] = [
        // A JWT header segment always encodes a JSON object, which base64url-encodes to a leading
        // "eyJ". Matching the credential's own shape catches it in any module and message format.
        (#"\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]+"#, "[REDACTED_JWT]"),

        // Mirrors the prefixes in CrossmintService's ApiKey, which this module can't import without
        // creating a dependency cycle.
        (#"\b(?:ck|sk)_(?:development|staging|production)_[A-Za-z0-9]{16,}"#, "[REDACTED_API_KEY]"),

        // Credentials with no distinguishing shape have to be matched by key name. Runs before the
        // container pattern below so a value nested deeper than one level is still caught.
        (#""(jwt|apiKey|encryptedOtp)"\s*:\s*"[^"]*""#, "\"$1\":\"[REDACTED]\""),

        // Whole credential containers, so a flat field added to one later is covered without
        // touching this file. Deeper nesting falls to the key-name pattern above.
        (#""?(authData|onboardingAuthentication)"?\s*:\s*[{\[][^{}\[\]]*[}\]]"#, "\"$1\":\"[REDACTED]\"")
    ].compactMap { pattern, replacement in
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        return (regex, replacement)
    }

    static func scrub(_ message: String) -> String {
        // One bridge into a mutable buffer for all patterns, rather than a fresh String per pass.
        let buffer = NSMutableString(string: message)
        var replacements = 0

        for entry in patterns {
            replacements += entry.regex.replaceMatches(
                in: buffer,
                range: NSRange(location: 0, length: buffer.length),
                withTemplate: entry.replacement
            )
        }

        return replacements == 0 ? message : buffer as String
    }

    static func scrub(_ attributes: [String: Encodable]?) -> [String: Encodable]? {
        attributes?.mapValues { value -> Encodable in
            if let string = value as? String {
                return scrub(string)
            }

            // Values keep their original type unless scrubbing actually changed something, so
            // numeric attributes aren't silently turned into strings.
            let rendered = String(describing: value)
            let scrubbed = scrub(rendered)
            return scrubbed == rendered ? value : scrubbed
        }
    }
}
