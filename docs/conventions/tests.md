# Test Conventions

Full reference: `docs/test-conventions.md`. Key rules inline:

## Framework and File Layout

- `import Testing` — not `import XCTest`
- Test types are `struct` — not `class`
- One test file per feature/concern: `Tests/<Module>Tests/<Domain>/<Feature>Tests.swift`
- Mocks in `Tests/<Module>Tests/Mocks/Mock<Protocol>.swift` (one mock per protocol)
- Helpers in `Tests/<Module>Tests/Helpers/<Feature>Helpers.swift`
- JSON fixtures in `Tests/<Module>Tests/Resources/<Fixture>.json`, registered in `Package.swift`

## Naming

- Test functions: `camelCase`, BDD-style, no verb prefix
- Good: `sendsOtpToValidEmail()`, `rejectsEmptyOtpCode()`, `returnsNilWhenWalletDoesNotExist()`
- Bad: `shouldSendOtp()`, `itCanReject()`, `willReturn()`, `canFetch()`
- Suite → Test names should read as a sentence: `Wallet Creation > rejects unknown chain string`
- Constants: `UPPER_SNAKE_CASE`
- Mock types: `Mock` prefix (`MockAuthService`, `MockSecureStorage`)

## `@Suite` and `@Test`

```swift
@Suite("Wallet Creation")
struct WalletCreationTests {
    @Test func createsEVMWalletWithApiKeySigner() async throws { }

    @Suite("when the chain is invalid")
    struct InvalidChainTests {
        @Test func rejectsUnknownChainString() throws { }
    }
}
```

## Assertions

| Macro | When |
|-------|------|
| `#expect(condition)` | General assertion — test continues on failure |
| `#require(condition)` | Halts test on failure (unwrapping, preconditions) |
| `#expect(throws: ErrorType.self) { }` | Verify throw by type |
| `#expect { } throws: { error in ... }` | Verify throw type and properties |

## Mock Pattern

```swift
final class MockAuthService: AuthService, @unchecked Sendable {
    var validateEmailCallCount = 0
    var validateEmailLastRequest: ValidateEmailRequest?
    var validateEmailError: AuthError?
    var validateEmailResponse = ValidateEmailResponse(emailId: "mock-email-id")

    func validateEmail(_ request: ValidateEmailRequest) async throws -> ValidateEmailResponse {
        validateEmailCallCount += 1
        validateEmailLastRequest = request
        if let error = validateEmailError { throw error }
        return validateEmailResponse
    }
}
```

Rules: track `callCount` + `lastRequest` per method. Make outcomes configurable via `var` with sensible defaults. `@unchecked Sendable` is fine here because mutations are test-isolated; use `actor` if the mock is accessed concurrently across tasks.

## Tagging

Define tags in `Tests/<AnyTarget>/Tags.swift`. Apply at suite level where possible:

```swift
extension Tag {
    @Tag static var unit: Self
    @Tag static var staging: Self
    @Tag static var critical: Self
    @Tag static var flaky: Self
}

@Suite("Wallet Creation", .tags(.critical))
struct WalletCreationTests { ... }
```

Staging tests: mark with `(STAG)` in the `@Test` display name and tag `.staging`. Use GUID-based Mailnesia detection for OTP (RSS items are not sorted chronologically).

## Test Philosophy

Hard-to-write tests are a signal to refactor production code, not to add test complexity. A test that requires complex setup is asking for a cleaner dependency injection point or more expressive return values.

Fix only the values relevant to what you're asserting and randomize everything else. When assertion logic grows complex across multiple tests, that logic belongs on the production type as a method, not in the test.

Avoid tests that only verify data routing — a mocked value passing through unchanged mirrors production logic and shares its blind spots. Focus on boundary conditions and transformations. Prefer factory-created objects with real data over mocks; reach for mocks only when the resource is unavailable in a test sandbox (network, disk, external services).

Tests must be fully isolated. Shared global state causes order-dependent failures that are expensive to diagnose.

## Hard Bans

- No `@Suite(.serialized)` — causes a Swift compiler ICE. Use actor or Task coordination instead.
- No `XCTest`
- No `class` test types
- No verb prefixes (`should`, `it`, `will`, `can`, `does`)
- No testing of implementation details — test observable behavior through public or `@testable` internal APIs
