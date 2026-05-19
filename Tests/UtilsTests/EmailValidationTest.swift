import Testing
@testable import Utils

@Suite("Email Validation Tests", .tags(.unit))
struct EmailValidationTests {
    @Test(
        "Rejects invalid emails",
        arguments: [
            "",
            "notanemail",
            "foo~&(&)(@bar.com",
            "a@b.com c@d.com"
        ]
    )
    func rejectsInvalidEmails(email: String) {
        #expect(!isValidEmail(email))
    }

    @Test(
        "Accepts valid emails",
        arguments: [
            "user@example.com",
            "user+tag@example.com",
            "user.name@sub.domain.org"
        ]
    )
    func acceptsValidEmails(email: String) {
        #expect(isValidEmail(email))
    }
}
