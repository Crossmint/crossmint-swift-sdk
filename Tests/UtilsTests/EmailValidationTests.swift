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
            ("Test.User@Domain.Org", "test.user@domain.org"),
            ("\tuser@example.com\n", "user@example.com"),
            ("First.Last@Gmail.com", "firstlast@gmail.com"),
            ("first.last@googlemail.com", "firstlast@gmail.com"),
            ("first.last+tag@gmail.com", "firstlast+tag@gmail.com"),
            (" First.Last@GoogleMail.com\n", "firstlast@gmail.com"),
            ("not-an-email", "not-an-email")
        ]
    )
    func lowercasesEmail(input: String, expected: String) {
        #expect(normalizeEmail(input) == expected)
    }
}
