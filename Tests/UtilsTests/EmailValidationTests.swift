import Testing
@testable import Utils

@Suite("Email Validation", .tags(.unit))
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

    @Test(
        "Lowercases email",
        arguments: [
            ("USER@EXAMPLE.COM", "user@example.com"),
            ("Test.User@Domain.Org", "test.user@domain.org")
        ]
    )
    func lowercasesEmail(input: String, expected: String) {
        #expect(normalizeEmail(input) == expected)
    }

    @Test(
        "Trims surrounding whitespace",
        arguments: [
            ("  user@example.com  ", "user@example.com"),
            ("\tuser@example.com\n", "user@example.com")
        ]
    )
    func trimsSurroundingWhitespace(input: String, expected: String) {
        #expect(normalizeEmail(input) == expected)
    }
}
