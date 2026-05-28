import SwiftEmailValidator

public func isValidEmail(_ email: String) -> Bool {
    return EmailSyntaxValidator.correctlyFormatted(email)
}

public func normalizeEmail(_ email: String) -> String {
    email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
}
