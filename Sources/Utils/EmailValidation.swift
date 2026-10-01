import SwiftEmailValidator

public func isValidEmail(_ email: String) -> Bool {
    return EmailSyntaxValidator.correctlyFormatted(email)
}

public func normalizeEmail(_ email: String) -> String {
    email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
}

package func normalizeSignerEmail(_ email: String) -> String {
    let lowercased = normalizeEmail(email)
    let parts = lowercased.split(separator: "@", maxSplits: 1, omittingEmptySubsequences: false)
    guard parts.count == 2 else { return lowercased }

    let domain = parts[1] == "googlemail.com" ? "gmail.com" : String(parts[1])
    let localPart = domain == "gmail.com" ? parts[0].replacingOccurrences(of: ".", with: "") : String(parts[0])
    return "\(localPart)@\(domain)"
}
