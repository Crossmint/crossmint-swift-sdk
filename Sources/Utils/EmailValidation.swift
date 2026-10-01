import SwiftEmailValidator

public func isValidEmail(_ email: String) -> Bool {
    return EmailSyntaxValidator.correctlyFormatted(email)
}

public func normalizeEmail(_ email: String) -> String {
    let trimmed = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    let parts = trimmed.split(separator: "@", maxSplits: 1, omittingEmptySubsequences: false)
    guard parts.count == 2 else { return trimmed }

    let domain = parts[1] == "googlemail.com" ? "gmail.com" : String(parts[1])
    let localPart = domain == "gmail.com" ? parts[0].replacingOccurrences(of: ".", with: "") : String(parts[0])
    return "\(localPart)@\(domain)"
}
