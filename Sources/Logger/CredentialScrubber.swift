//
//  CredentialScrubber.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 04/08/26.
//

import Foundation

enum CredentialScrubber {
    static let patterns: [(regex: NSRegularExpression, replacement: String)] = [
        (#"\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]+"#, "[REDACTED_JWT]"),
        (#"\b(?:ck|sk)_(?:development|staging|production)_[A-Za-z0-9]{16,}"#, "[REDACTED_API_KEY]"),
        (#""(jwt|apiKey|encryptedOtp)"\s*:\s*"[^"]*""#, "\"$1\":\"[REDACTED]\""),
        (#""?(authData|onboardingAuthentication)"?\s*:\s*[{\[][^{}\[\]]*[}\]]"#, "\"$1\":\"[REDACTED]\"")
    ].compactMap { pattern, replacement in
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        return (regex, replacement)
    }

    static func scrub(_ message: String) -> String {
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
            guard let string = value as? String else { return value }
            return scrub(string)
        }
    }
}
