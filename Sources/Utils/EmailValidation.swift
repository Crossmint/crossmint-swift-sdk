import SwiftEmailValidator

public func isValidEmail(_ email: String) -> Bool {
    return EmailSyntaxValidator.correctlyFormatted(email)
}
