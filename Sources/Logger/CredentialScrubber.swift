//
//  CredentialScrubber.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 04/08/26.
//

import Foundation

enum CredentialScrubber {
    struct Pattern {
        let regex: NSRegularExpression
        let replacement: String

        init?(_ expression: String, replacedWith replacement: String) {
            guard let regex = try? NSRegularExpression(pattern: expression) else { return nil }
            self.regex = regex
            self.replacement = replacement
        }
    }

    private static let credentialValues = [
        Pattern(
            #"\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]+"#,
            replacedWith: "[REDACTED_JWT]"
        ),
        Pattern(
            #"\b(?:ck|sk)_(?:development|staging|production)_[A-Za-z0-9]{16,}"#,
            replacedWith: "[REDACTED_API_KEY]"
        )
    ]

    private static let credentialKeys = [
        Pattern(
            #""(jwt|apiKey|encryptedOtp)"\s*:\s*"[^"]*""#,
            replacedWith: #""$1":"[REDACTED]""#
        ),
        Pattern(
            #""?(authData|onboardingAuthentication)"?\s*:\s*[{\[][^{}\[\]]*[}\]]"#,
            replacedWith: #""$1":"[REDACTED]""#
        )
    ]

    private static let emailLocalPart = #"\p{L}\p{M}\p{N}!#$%&'*+/=?^_`{|}~"#
    private static let emailDomain = #"[\p{L}\p{M}\p{N}-]+(?:\.[\p{L}\p{M}\p{N}-]+)*\.[\p{L}\p{M}]{2,}"#
    private static let phoneNumber = #"\+?\(?\d[\d ().-]*\d"#

    private static let locatorSeparator = "(?::|%3[Aa])"

    private static let personalData = [
        Pattern(
            #"(^|[^\#(emailLocalPart).-])[\#(emailLocalPart)-](?:[\#(emailLocalPart).-]|\\/)*(?:@|%40)\#(emailDomain)"#,
            replacedWith: "$1***"
        ),
        Pattern(
            #"\\?"(?:[^"\\\n]|\\[^"])*\\?"@\#(emailDomain)"#,
            replacedWith: "***"
        ),
        Pattern(
            #"(^|[^A-Za-z0-9])(phone(?:Number)?:)\#(phoneNumber)"#,
            replacedWith: "$1$2***"
        ),
        Pattern(
            #"("phone(?:Number)?"\s*:\s*")\#(phoneNumber)""#,
            replacedWith: #"$1***""#
        ),
        Pattern(
            #"(^|[^A-Za-z0-9])((?:twitter|x|userId)\#(locatorSeparator))(?:(?!%3[Aa])[^:\s"\\])+"#,
            replacedWith: "$1$2***"
        ),
        Pattern(
            #"(^|[^A-Za-z0-9])((?:email|phone(?:Number)?)\#(locatorSeparator))(?:(?!%3[Aa])[^:\s"\\/?&#])+"#,
            replacedWith: "$1$2***"
        )
    ]

    static let patterns = (credentialValues + credentialKeys + personalData).compactMap { $0 }

    static func scrub(_ message: String) -> String {
        let buffer = NSMutableString(string: message)
        var replacements = 0

        for pattern in patterns {
            replacements += pattern.regex.replaceMatches(
                in: buffer,
                range: NSRange(location: 0, length: buffer.length),
                withTemplate: pattern.replacement
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
