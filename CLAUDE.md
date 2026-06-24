# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Development Commands

### Building the SDK
```bash
# Build using xcodebuild directly
make build
```

### Running Tests
```bash
# Run tests with xcodebuild (includes demo app builds)
make test

# Run tests with CI configuration (includes lint check)
make ci-test

# Run specific test target
xcodebuild -scheme CrossmintClientSDK -destination "platform=iOS Simulator,name=iPhone 17 Pro,OS=latest" test
```

### Linting
```bash
# Run SwiftLint to check for issues
make lint

# Run SwiftLint with auto-fix
make lint-fix

# Using swift package directly
swift package plugin --allow-writing-to-package-directory swiftlint --fix
```

### Demo Applications
```bash
# Build the EVM demo app (SmartWalletsDemo)
make build-evm-demo
```

### Other Commands
```bash
# Clean build artifacts
make clean

# Resolve Swift package dependencies
make resolve

# Open in Xcode
make open
# or double-click "Crossmint SDK.xcworkspace"
```

## Architecture Overview

The Crossmint Swift SDK follows a layered architecture with a configured singleton as the entry point, domain services for API communication, and chain-specific `Wallet` subclasses as the primary consumer-facing type.

### Layered Architecture

```
CrossmintSDK.shared                     (@MainActor final class)
  ├── .crossmintWallets  (CrossmintWallets)
  ├── .authClient        (AuthClient protocol)
  ├── .authManager       (CrossmintAuthManager)
  ├── .crossmintService  (CrossmintService — internal detail, avoid in app code)
  └── setJWT(_:)

CrossmintWallets
  └── getOrCreate(chain:signer:options:) → Wallet subclass

Wallet (open class — @unchecked Sendable)
  ├── balances(_:_:) / nfts(page:nftsPerPage:) / listTransfers(tokens:)
  ├── signers() / signerIsRegistered(_:)
  └── EVMWallet / SolanaWallet / StellarWallet (chain-specific subclasses)
      [transaction/signing logic in Wallet+Transactions.swift extensions]

--- INTERNAL ---
Services (structs — single-responsibility API calls)
  WalletService / TransactionService / TransferService
  BalanceService / NFTService / SignatureService / SignerRegistrationService

Infrastructure
  CrossmintAuth / Logger / SecureStorage / HTTP Client / DeviceSigner
```

### SDK Entry Point

`CrossmintSDK` is a `@MainActor final class` in the `CrossmintClient` module:

```swift
// Configure once, early in app startup
CrossmintSDK.configure(apiKey: "ck_staging_...", logLevel: .error)

// Developer-managed auth (production — your backend issues the JWT)
await CrossmintSDK.shared.setJWT(myJWT)
await CrossmintSDK.shared.setJWT(nil)  // sign out

// Crossmint-managed auth (email/phone OTP)
let authClient = CrossmintSDK.shared.authClient  // AuthClient protocol

// Wallet access
let wallets = CrossmintSDK.shared.crossmintWallets
```

Environment (staging vs production) is decoded from the API key format — never pass it explicitly. `crossmintService` is still a public property on the singleton but is an HTTP implementation detail — don't use it in application code.

### Package Boundaries

```
CrossmintClient       ← SDK singleton (CrossmintSDK), SwiftUI integration, environment values
CrossmintAuth         ← AuthClient protocol, OTP flow, JWT management
Wallet                ← Wallet class, domain services, signers
CrossmintCommonTypes  ← shared types (Chain, CryptoCurrency, BlockchainType, etc.)
CrossmintService      ← HTTP client, request building, error mapping
DeviceSigner          ← Secure Enclave key storage (zero external dependencies)
Passkeys              ← Passkey authentication support
SecureStorage         ← Keychain-based secure storage
Http / Logger / Utils / Web ← infrastructure
```

### Wallet

`Wallet` is an `open class` with `@unchecked Sendable`. Sign/poll logic lives in `Wallet+Transactions.swift` extensions. Chain-specific subclasses (`EVMWallet`, `SolanaWallet`, `StellarWallet`) extend it with chain-unique methods.

Add `.crossmintNonCustodialSigner()` to your root view when using email/phone signers — this injects the hidden WebView required for TEE communication.

### TEE Architecture

The TEE WebView lives in the `Wallet` module (`CrossmintTEE`). It handles auto-recovery from WebKit content-process termination internally. TEE is an implementation detail of email/phone signers — developers never interact with it directly.

### Auth State

`CrossmintAuthManager` manages JWT state, persisting it to keychain. `setJWT(_:)` on the singleton stores a developer-supplied token (no refresh). `AuthClient.verifyOTP()` stores a JWT from Crossmint-managed auth. HTTP requests in the `Wallet` module inject the current JWT via `AuthenticatedCrossmintService`.

### Error Protocol

All new error types must conform to `CrossmintError`:

```swift
public protocol CrossmintError: Error, Sendable {
    var code: String { get }               // SCREAMING_SNAKE_CASE
    var message: String { get }
    var recoverySuggestion: String? { get }
    var underlyingError: Error? { get }
}
```

Domain errors: `WalletError`, `TransactionError`, `SignatureError`, `AuthError`.

### Services

Services make exactly one API call per method — no coordination, no polling. Multi-step flows (getOrCreate, sign + poll) live in the client (`DefaultCrossmintWallets`) or in `Wallet+Transactions.swift` extensions. Never embed flow logic or polling inside a service method.

## Code Conventions

### Protocol-First Design

Expose behavior through protocols, keep concrete types internal. Protocols live in the same module as their primary consumer; implementations are `internal` or `package` unless they need to be subclassed. External consumers only import protocols and public value types.

### Naming

Variable names must not duplicate the type or the name of the containing object:

```swift
// Bad — duplicates type info, duplicates containing type name
struct Wallet {
    var walletAddress: String   // "wallet" already in Wallet
    var isValid: Bool           // "is" prefix duplicates Bool
    var creationDate: Date      // "Date" redundant
}

// Good
struct Wallet {
    var address: String
    var valid: Bool
    var createdOn: Date
}
```

Avoid vague verbs (`manage`, `handle`, `process`) in function and type names — they obscure responsibility. Use specific action names: `validateOrder`, `persistPayment`, `signTransaction`.

Functions should do one thing. A name that requires "and" is a signal to split: `validateAndPersist` → `validate` + `persist`.

### Abstraction Discipline

Inline code unless the abstraction meets one of these criteria:
- It self-documents a non-obvious relationship or hides significant complexity
- It maintains state the algorithm requires across iterations
- It has multiple, current implementations (e.g. a protocol with two concrete types in active use)

A helper function that just renames a call, or a type that wraps only one thing, adds indirection without value. Remove it.

### Business Logic Placement

Business logic lives in the client layer (`DefaultCrossmintWallets`, wallet extensions), not in services. Services are generic and unaware of business context — they make API calls and return data. Coordination, polling, and retry belong in the client or wallet layer.

### Actors for Mutable Async State

Use `actor` for any type that holds mutable state accessed from multiple async contexts. Never use `@unchecked Sendable` — fix the root cause (isolate to an actor or make the state immutable). If a framework type requires `@unchecked Sendable` on a mock, that is acceptable, but document why.

### Optional JSON Body Fields

Synthesized `Encodable` encodes `nil` optionals as `null`, which many APIs reject or misinterpret. When a field should be omitted from the body when `nil`, always implement `CodingKeys` + `encodeIfPresent` manually:

```swift
// Wrong — synthesized Encodable sends null for nil signer
struct TransferBody: Encodable {
    let to: String
    let signer: String?  // encodes as null
}

// Right — encodeIfPresent omits the field entirely
struct TransferBody: Encodable {
    let to: String
    let signer: String?

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(to, forKey: .to)
        try container.encodeIfPresent(signer, forKey: .signer)
    }
}
```

### Simple Expressions Over Chains

Split complex one-liners into named intermediate steps. Clarity beats brevity:

```swift
// Avoid — what does this do?
let result = try await service.fetch(id: pending.pendingApproval?.id ?? "").flatMap { ... }

// Prefer — each step is obvious
guard let approvalId = pending.pendingApproval?.id else { return }
let approval = try await service.fetch(id: approvalId)
```

### Public API Surface Discipline

Before making anything `public`, ask: who outside this module calls this? If the answer is "only sibling modules," use `package` access. If the answer is "nobody yet," keep it `internal`. Exposing unnecessary public surface makes future refactors painful and forces semver consideration.

The same applies to stored properties: if a property is only read during `init`, use a local variable instead.

### Error Type Requirements

All new error types must conform to `CrossmintError`. Error codes use `SCREAMING_SNAKE_CASE` (e.g., `WALLET_NOT_FOUND`). Provide a `recoverySuggestion` whenever the developer can take a specific action to fix the problem. Errors communicate exactly two things: whether the caller should retry, and whether the fault is theirs or the system's. Don't create subclasses or cases beyond what's needed to express those two distinctions.

### Function Inputs

Functions should depend only on what they use. Prefer passing specific values over large objects when only a subset of fields is needed — this keeps the function usable in a wider range of contexts and makes its dependencies explicit.

### Complexity Threshold

Before adding background tasks, timers, or retry loops, check whether a simpler pre-call check would suffice, and whether the other SDKs (React Native, Kotlin) do the same thing. Complexity that isn't warranted by the feature and not matched cross-platform creates drift.

### Swift Concurrency Patterns

**Typed throws.** Use domain-typed errors where the failure set is known at the call site. The codebase uses `throws(WalletError)`, `throws(TransactionError)`, etc. Don't use untyped `throws` for internal methods whose errors are knowable — the compiler enforces exhaustiveness and eliminates the need for casts.

**`@MainActor` propagation.** `CrossmintSDK` is `@MainActor`. Code that updates UI or calls into the singleton must run on the main actor. Use `await MainActor.run { }` to hop explicitly rather than `DispatchQueue.main.async` — that is UIKit-era code that breaks structured concurrency.

**Structured concurrency.** Use `async let` for parallel independent calls. Use `TaskGroup` when the fan-out count is dynamic. Avoid `Task.detached` unless you explicitly need to break task inheritance (priority, cancellation, actor context) — detached tasks orphan work and make testing harder.

## Test Conventions

Full reference: `docs/test-conventions.md`. Key rules inline:

### Framework and File Layout

- `import Testing` — not `import XCTest`
- Test types are `struct` — not `class`
- One test file per feature/concern: `Tests/<Module>Tests/<Domain>/<Feature>Tests.swift`
- Mocks in `Tests/<Module>Tests/Mocks/Mock<Protocol>.swift` (one mock per protocol)
- Helpers in `Tests/<Module>Tests/Helpers/<Feature>Helpers.swift`
- JSON fixtures in `Tests/<Module>Tests/Resources/<Fixture>.json`, registered in `Package.swift`

### Naming

- Test functions: `camelCase`, BDD-style, no verb prefix
- Good: `sendsOtpToValidEmail()`, `rejectsEmptyOtpCode()`, `returnsNilWhenWalletDoesNotExist()`
- Bad: `shouldSendOtp()`, `itCanReject()`, `willReturn()`, `canFetch()`
- Suite → Test names should read as a sentence: `Wallet Creation > rejects unknown chain string`
- Constants: `UPPER_SNAKE_CASE`
- Mock types: `Mock` prefix (`MockAuthService`, `MockSecureStorage`)

### `@Suite` and `@Test`

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

### Assertions

| Macro | When |
|-------|------|
| `#expect(condition)` | General assertion — test continues on failure |
| `#require(condition)` | Halts test on failure (unwrapping, preconditions) |
| `#expect(throws: ErrorType.self) { }` | Verify throw by type |
| `#expect { } throws: { error in ... }` | Verify throw type and properties |

### Mock Pattern

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

Rules: track `callCount` + `lastRequest` per method. Make outcomes configurable via `var` with sensible defaults. Use `actor` instead of `@unchecked Sendable` when the mock holds mutable async state.

### Tagging

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

### Test Philosophy

Hard-to-write tests are a signal to refactor production code, not to add test complexity. Tests are consumers of production interfaces — a test that requires a complex setup is asking for a cleaner dependency injection point or more expressive return values.

When assertion logic grows complex (e.g. asserting 20 individual fields across multiple tests), that logic belongs on the production type as a method (like `isEqual`), not in the test.

Each test case should be a distinct set of inputs and an expected output. Fix only the values relevant to what you're asserting and randomize everything else — incidental state should be invisible so readers immediately see what the test proves.

Build a testing fabric where each layer tests different assumptions. Avoid tests that only verify data routing (a mocked value passes through unchanged, a parameter is forwarded to a dependency) — they mirror production logic and share its blind spots. Focus on boundary conditions and transformations.

Mocks should only be used when there is no alternative — typically for resources unavailable in a test sandbox (network, disk, external services). Prefer factory-created objects with real or randomized data over mocks wherever possible.

Tests must be fully isolated. Shared global state causes order-dependent failures that are expensive to diagnose.

### Hard Bans

- No `@Suite(.serialized)` — causes a Swift compiler ICE. Use actor or Task coordination instead.
- No `XCTest`
- No `class` test types
- No verb prefixes (`should`, `it`, `will`, `can`, `does`)
- No testing of implementation details — test observable behavior through public or `@testable` internal APIs

## Common Mistakes to Avoid

- **Storing init-only values as properties.** If a value is used during `init` and never again, assign it to a local, not `self.property`. Stored properties signal that the value is needed beyond init.

- **Leaking internal types into the public API.** The HTTP client (`crossmintService`), internal service types, and factory classes must not appear in any public protocol or `public` property. Before adding a `public` property, ask whether external developers actually need it.

- **Synthesized `Encodable` with optional fields.** Synthesized conformance encodes `nil` as `null`. For any request body with optional fields, use `CodingKeys` + `encodeIfPresent`. See Code Conventions above.

- **`@unchecked Sendable` to suppress concurrency errors.** This hides real data races. Fix the isolation instead — move state to an actor, make the type a value type, or properly annotate `@MainActor`.

- **Adding a timer or background refresh without cross-SDK justification.** Always check whether a simpler pre-call expiry check would work, and whether the React Native and Kotlin SDKs do the same. Background tasks that aren't matched cross-platform create platform drift and maintenance burden.

- **Chaining optional access with complex fallbacks in one expression.** Break it into steps. One-liners that need a comment to explain what they do should be multiple lines.

- **Embedding flow logic in a service method.** Services make exactly one API call. Coordination, polling, and retry belong in the client or wallet layer.

- **Hardcoding environment or API version strings.** Environment comes from the API key. API versions come from a centralized constant or the OpenAPI generated client.

## Documentation Rules

Document only what cannot be derived from the code or its version history.

- Comments and doc comments should only explain **why**, never **what** or **how** — if the what requires explanation, the code needs to be renamed or restructured.
- TODOs should describe why something is suboptimal, not propose solutions (solutions change; the underlying problem is what matters).
- Place documentation alongside the authoritative source whose scope it belongs to: code comments for code-level context, PR descriptions for why a decision was made.
- State each idea exactly once. Don't preview in an introduction what the detail immediately below already covers.

## Development Workflow

1. All code must pass SwiftLint checks before merging (`make lint`).
2. Tests run on iPhone 17 Pro simulator by default.
3. The SDK uses Swift Package Manager for dependency management.
4. SwiftLint is integrated as a build tool plugin.
5. Set these environment variables when running the demo app:
   - `CROSSMINT_API_KEY` — your Crossmint API key
   - `CROSSMINT_WHITELISTED_DOMAIN` — whitelisted domain for the SDK
