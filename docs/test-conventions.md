# Crossmint Swift SDK — Test Suite Conventions

> Applies to `crossmint-swift-sdk`. Swift-specific edition of the cross-repo test conventions.

---

## 1. Guiding Principles

- **Consistency over preference** — one way to do things, everywhere.
- **Readability as documentation** — a test name should explain itself without reading the code.
- **Scalability** — must support unit, integration, and staging tests as the SDK grows.
- **Tests live with their module** — each test target mirrors its source module.
- **Mock at the boundary** — mock protocols, not concrete implementations.

---

## 2. Folder Structure

```
Tests/
  <ModuleNameTests>/
    <Domain>/
      <Feature>Tests.swift          ← test file per feature or concern
    Mocks/
      Mock<ProtocolName>.swift      ← one mock per protocol
    Helpers/
      <Feature>Helpers.swift        ← shared setup / factory functions
    Resources/
      <FixtureName>.json            ← JSON fixtures for decode tests
```

Staging integration tests live inside `CrossmintClientTests/` alongside unit tests and are identified by `(STAG)` in their `@Test` display name.

**Key paths:**

| Artifact | Path |
|----------|------|
| Test file | `Tests/<Module>Tests/<Domain>/<Feature>Tests.swift` |
| Mock | `Tests/<Module>Tests/Mocks/Mock<Protocol>.swift` |
| Helper | `Tests/<Module>Tests/Helpers/<Feature>Helpers.swift` |
| JSON fixture | `Tests/<Module>Tests/Resources/<Fixture>.json` |
| Staging tests | `Tests/CrossmintClientTests/StagingIntegrationTests.swift` |

---

## 3. File Naming Conventions

| Type | Convention | Example |
|------|-----------|---------|
| Test files | `PascalCaseTests.swift` | `WalletCreationTests.swift` |
| Mock files | `Mock<Protocol>.swift` | `MockAuthService.swift` |
| Helper files | `PascalCaseHelpers.swift` | `CrossmintTEEHelpers.swift` |
| JSON fixtures | `PascalCase.json` | `WalletEVMApiKey.json` |

---

## 4. Code Naming Conventions

**Test functions — camelCase, BDD-style, no verb prefix**

```swift
// Good
@Test func sendsOtpToValidEmail() async throws { }
@Test func rejectsEmptyOtpCode() async throws { }
@Test func returnsNilWhenWalletDoesNotExist() async throws { }

// Avoid — verb/modal prefix adds no information
@Test func shouldSendOtpToValidEmail() async throws { }
@Test func itCanRejectInvalidEmail() async throws { }
@Test func willParseWalletApiModel() async throws { }
```

**Constants — `UPPER_SNAKE_CASE`**

```swift
static let MAX_RETRY_ATTEMPTS = 3
static let DEFAULT_STAGING_CHAIN = "base-sepolia"
```

**Mock types — `Mock` prefix, PascalCase**

```swift
final class MockAuthService: AuthService, @unchecked Sendable { }
actor MockSecureStorage: SecureStorage { }
```

**Helper functions — camelCase, intent-describing**

```swift
func makeDefaultWallet(chain: Chain = .baseSepolia) -> Wallet { }
func makeRefreshJWTResponse(expiresAt: Double = 4102444800) -> RefreshJWTResponse { }
```

---

## 5. Test Naming — BDD Style

Structure tests as: **Suite** (subject) → **Test** (behaviour), or **Suite** (subject) → nested **Suite** (context) → **Test** (behaviour).

The test name states the behaviour directly — no `should/can/does/will` prefix. The verb comes from the action itself.

```swift
// Good — @Suite groups the subject, @Test states the behaviour
@Suite("Wallet Creation")
struct WalletCreationTests {

    @Test func createsEVMWalletWithApiKeySigner() async throws { }
    @Test func createsSolanaWalletWithApiKeySigner() async throws { }

    @Suite("when the chain is invalid")
    struct InvalidChainTests {
        @Test func rejectsEmptyChainString() throws { }
        @Test func rejectsUnknownChainString() throws { }
    }
}

// Good — flat when context is obvious from the suite name
@Suite("Email Validation")
struct EmailValidationTests {
    @Test(arguments: ["notanemail", "@no-local", "a@b"])
    func rejectsInvalidEmailFormat(email: String) throws { }
}
```

A test name should read as a sentence when prefixed with its suite chain:

> `Wallet Creation > when the chain is invalid > rejects unknown chain string`

**Avoid** verb prefixes that add no information:

```swift
// Avoid
@Test func shouldCreateEVMWallet() { }
@Test func itCanRejectInvalidEmail() { }
@Test func willParseWalletApiModel() { }
@Test func canReturnNilForMissingWallet() { }
```

---

## 6. Test Tagging

Define project-wide tags in a shared file inside each test target and apply them with the `.tags()` trait.

**Tag definitions** — add to `Tests/<AnyTarget>/Tags.swift`:

```swift
import Testing

extension Tag {
    @Tag static var unit: Self
    @Tag static var staging: Self
    @Tag static var critical: Self
    @Tag static var flaky: Self
}
```

**Applying tags:**

```swift
// Good — tag on @Suite applies to all tests inside
@Suite("Wallet Creation", .tags(.critical))
struct WalletCreationTests { ... }

// Good — tag on individual test when it differs from the suite
@Suite("Signer Management")
struct SignerManagementTests {
    @Test(.tags(.staging))
    func signerIsRegisteredOnStaging() async throws { }
}
```

| Tag | Meaning |
|-----|---------|
| `.unit` | Pure unit test — no network, no simulator I/O |
| `.staging` | Requires a live `staging.crossmint.com` connection |
| `.critical` | Must pass on every PR |
| `.flaky` | Temporarily skipped in CI — must include a `TODO` with a ticket reference |

**Disabling flaky tests:**

```swift
@Test(.disabled("TODO(ENG-1234): race condition in OTP timing — re-enable after fix"))
func sendsOtpUnderLoad() async throws { }
```

**Running by tag (Swift Testing CLI):**

```bash
# Swift 6.1+ tag filter
swift test --filter tag:staging

# Or control via the xctestplan — see CrossmintSDK.xctestplan
```

---

## 7. Mock Patterns

All mocks live in `Tests/<Module>Tests/Mocks/`. Each mock implements exactly one protocol.

### Standard mock (synchronous or simple async)

```swift
import Foundation
@testable import CrossmintAuth

final class MockAuthService: AuthService, @unchecked Sendable {

    // MARK: - Call tracking
    var validateEmailCallCount = 0
    var validateEmailLastRequest: ValidateEmailRequest?

    // MARK: - Configurable outcomes
    var validateEmailError: AuthError?
    var validateEmailResponse = ValidateEmailResponse(emailId: "mock-email-id")

    // MARK: - Protocol implementation
    func validateEmail(_ request: ValidateEmailRequest) async throws -> ValidateEmailResponse {
        validateEmailCallCount += 1
        validateEmailLastRequest = request
        if let error = validateEmailError { throw error }
        return validateEmailResponse
    }

    // MARK: - Default factories
    static func makeDefaultRefreshJWTResponse() -> RefreshJWTResponse {
        // Use a far-future Unix timestamp, not ISO-8601
        RefreshJWTResponse(jwt: "mock-jwt", expiresAt: 4102444800)
    }
}
```

### Actor-based mock (for mutable async state)

```swift
actor MockSecureStorage: SecureStorage {
    private var storage: [String: Data] = [:]

    func save(_ data: Data, key: String) throws { storage[key] = data }
    func load(key: String) throws -> Data? { storage[key] }
    func delete(key: String) throws { storage[key] = nil }
}
```

**Rules:**
- Mark mocks `@unchecked Sendable` (or use `actor`) — never omit concurrency annotations.
- Track every call: `callCount` + `lastRequest` for each method.
- Make outcomes configurable via `var` properties with sensible defaults.
- Provide `static` factory methods for common response objects.

---

## 8. JSON Fixtures

JSON fixtures decode real server responses for offline testing. They must exactly match the shape of the production response.

**Location:** `Tests/<Module>Tests/Resources/<Fixture>.json`

**Registration** — add to the target in `Package.swift`:

```swift
.testTarget(
    name: "WalletTests",
    dependencies: [...],
    resources: [
        .copy("Resources/WalletEVMApiKey.json"),
        .copy("Resources/WalletSolanaEmail.json"),
    ]
)
```

**Loading pattern** (via `TestsUtils`):

```swift
import TestsUtils

let wallet: WalletApiModel = try GetFromFile.getModelFrom(
    fileName: "WalletEVMApiKey",
    bundle: .module
)
```

**Fixture naming:**

| Category | Example |
|----------|---------|
| Wallet instance | `WalletEVMApiKey.json`, `WalletSolanaEmail.json` |
| Wallet config | `SmartWalletConfigResponseEOA.json` |
| Transaction | `CreateTransactionAwaitingApproval.json` |
| Transfer history | `ListTransfersResponse.json` |
| Signature | `CreateSignatureAwaitingApproval.json` |

---

## 9. Assertions

| Macro | When to use |
|-------|-------------|
| `#expect(condition)` | General assertion — test continues on failure |
| `#require(condition)` | Assertion that halts the test on failure |
| `#expect(throws: ErrorType.self) { }` | Verify a throw by type only |
| `#expect { } throws: { error in ... }` | Verify throw type **and** message/properties |

```swift
// Verify a specific error type
#expect(throws: WalletError.invalidChain) {
    try wallet.assertValidForEnvironment(.production)
}

// Unwrap optional — halts the test if nil
let address = try #require(wallet.address)
#expect(address.hasPrefix("0x"))

// Capture and inspect the error
#expect {
    try riskyOperation()
} throws: { error in
    guard let walletError = error as? WalletError else { return false }
    return walletError == .walletNotFound
}
```

---

## 10. Parameterized Tests

Use `arguments:` for exhaustive input coverage without duplicating test bodies:

```swift
@Test("rejects invalid API key formats", arguments: [
    "",
    "not_a_key",
    "sk_live_oldformat",
])
func rejectsInvalidApiKeyFormat(key: String) throws {
    #expect(throws: ApiKeyError.self) {
        try ApiKey(key)
    }
}

// Enum exhaustiveness
@Test("parses all known environment prefixes",
      arguments: ApiKeyEnvironmentPrefix.allCases)
func parsesKnownEnvironmentPrefix(prefix: ApiKeyEnvironmentPrefix) throws {
    // assert parsing succeeds for every case
}
```

---

## 11. Staging Integration Tests

Staging tests make real network calls against `staging.crossmint.com`. They live in `StagingIntegrationTests.swift` and are identified by `(STAG)` in the `@Test` display name.

### Shared context actor

Use a shared `actor` to run the auth + wallet-creation flow only once per test session:

```swift
actor StagingTestContext {
    private var _wallets: (evm: EVMWallet, solana: SolanaWallet)?

    func getOrInitializeWallets() async throws -> (evm: EVMWallet, solana: SolanaWallet) {
        if let w = _wallets { return w }
        let w = try await authenticateAndCreateWallets()
        _wallets = w
        return w
    }
}

private let stagingCtx = StagingTestContext()
```

### OTP via Mailnesia

```swift
let testEmail = "crossmint-swift-sdk-test@mailnesia.com"

// Snapshot existing GUIDs before triggering OTP
let before = try await MailnesiaReader.fetchGUIDs(inbox: "crossmint-swift-sdk-test")

// Send OTP
_ = try await authManager.sendEmailOtp(email: testEmail)

// Poll for a new GUID and extract the 6-digit code
let otp = try await MailnesiaReader.waitForNewOTP(
    inbox: "crossmint-swift-sdk-test",
    knownGUIDs: before
)
```

**Rules:**
- Always use GUID-based detection — Mailnesia RSS items are **not** sorted chronologically.
- Staging sends two emails per OTP (HTML + plain text); check all new GUIDs for the code.
- Mark every staging test `(STAG)` in its display name and tag it `.staging`.

---

## 12. Concurrency

- Tests that interact with `@MainActor`-isolated types must be annotated `@MainActor`.
- Do **not** use `@Suite(.serialized)` — it causes a Swift compiler crash (ICE) in the current toolchain. Use `Task`-based coordination or actor patterns instead.
- Shared test state across async tests must be protected by an `actor`.

```swift
@MainActor
@Suite("WebView Message Handler")
struct WebViewMessageHandlerTests {
    @Test func handlesAuthenticationMessage() async throws { ... }
}
```

---

## 13. What NOT to Do

- **Do not use `XCTest`** — all tests use Swift Testing (`import Testing`).
- **Do not use `class` for test types** — use `struct`.
- **Do not use `@Suite(.serialized)`** — causes compiler ICE; coordinate via `actor` or `Task` instead.
- **Do not add verb prefixes** (`should`, `it`, `will`, `can`, `does`) to function names.
- **Do not test implementation details** — test observable behaviour through public or `@testable` internal APIs.
- **Do not rely on staging to catch failures that can be tested locally** — unit tests must fail offline wherever possible.

---

## 14. Migration Checklist

When adding or migrating a test file:

- [ ] File placed under `Tests/<Module>Tests/<Domain>/<Feature>Tests.swift`
- [ ] File named `PascalCaseTests.swift`
- [ ] Test type is `struct`, not `class`
- [ ] `import Testing` (not `import XCTest`)
- [ ] Test functions are camelCase, BDD-style, **no verb prefix**
- [ ] Mock files in `Mocks/`, named `Mock<Protocol>.swift`
- [ ] JSON fixtures in `Resources/`, registered in `Package.swift`
- [ ] Constants named `UPPER_SNAKE_CASE`
- [ ] Tags applied at `@Suite` level where possible
- [ ] Staging tests marked `(STAG)` in display name and tagged `.staging`
- [ ] No `@Suite(.serialized)` — replaced with actor or Task coordination

---

## 15. Quick Reference

| | |
|---|---|
| Test type | `struct`, `import Testing` |
| Test function | `@Test func doesSomething() { }` |
| Suite | `@Suite("Subject") struct SubjectTests { }` |
| Assertion | `#expect(value == expected)` |
| Optional unwrap | `let x = try #require(optional)` |
| Error assertion | `#expect(throws: MyError.self) { try fn() }` |
| Parameterized | `@Test(arguments: [...]) func test(_ arg: T) { }` |
| Mock location | `Tests/<Module>Tests/Mocks/Mock<Protocol>.swift` |
| Fixture loading | `GetFromFile.getModelFrom(fileName:bundle:.module)` |
| No verb prefixes | `sendsOtp()` not `shouldSendOtp()` / `willSendOtp()` |
| Tags | `.tags(.unit)` `.tags(.staging)` `.tags(.critical)` |
| Staging marker | `(STAG)` suffix in `@Test("... (STAG)")` display name |
| Avoid | `@Suite(.serialized)`, `XCTest`, `class` test types |
