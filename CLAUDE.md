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
xcodebuild -scheme CrossmintClientSDK -destination "platform=iOS Simulator,name=iPhone 16 Pro,OS=latest" test
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

The Crossmint Swift SDK is being refactored toward a layered architecture defined in the [Mobile SDK API Review EDD](https://linear.app/crossmint/project/mobile-sdk-api-review-182dfa4d5add/overview). The sections below describe the **target architecture** — some parts are in flight. See the in-flight work list at the end of this section.

### Layered Architecture

```
CrossmintSDK.shared                     (configured singleton — @MainActor)
  ├── .wallets  (WalletClient protocol)
  ├── .auth     (AuthClient protocol)
  └── setJWT(_:)

WalletClient
  └── getOrCreate(chain:signer:options:) → any Wallet
  └── get(locator:) → any Wallet

Wallet (protocol — returned by WalletClient)
  ├── send(to:token:amount:)
  ├── sendTransaction(_:) / createTransaction(_:) / approve(transactionId:)
  ├── signMessage(_:)
  ├── balances(tokens:) / nfts(page:perPage:)
  └── delegatedSigners() / addDelegatedSigner(_:)

--- INTERNAL ---
Orchestrators (actors — coordinate multi-step flows)
  ├── WalletOrchestrator   (getOrCreate flow)
  └── TransactionOrchestrator  (send, sign, poll)

Services (structs — single-responsibility API calls)
  WalletService / TransactionService / TransferService
  BalanceService / NFTService / SignatureService

Infrastructure
  AuthState (actor) / Logger / SecureStorage / HTTP Client
```

### SDK Entry Point

The singleton lives in `CrossmintCore`. Configuration wires together all clients:

```swift
// Simple setup
CrossmintSDK.configure(apiKey: "ck_staging_...")

// Advanced
CrossmintSDK.configure(with: Configuration(apiKey: "ck_staging_...", logLevel: .debug))

// Custom auth (production)
await CrossmintSDK.shared.setJWT(myJWTFromMyBackend)
// Set to nil on sign out
```

Environment (staging vs production) is decoded from the API key format — never pass it explicitly.

### Package Boundaries (Target)

```
CrossmintCore          ← singleton shell, protocols, config, auth state, errors
CrossmintTEE           ← TEEProvider protocol + MockTEEProvider (depends on Core)
CrossmintWalletsImpl   ← wallet client, signers, orchestrators, services (depends on Core + TEE)
CrossmintAuthImpl      ← auth client, OTP flow (depends on Core)
CrossmintCheckoutImpl  ← checkout client + embedded view (depends on Core)
CrossmintSDKProduct    ← assembly: configure() + wiring (depends on Core + TEE + all impls)
```

Public product imports: `CrossmintSDK` (everything), `CrossmintWallets`, `CrossmintAuth`.

### Wallet Protocol & Signers

`Wallet` is a public protocol — not a class. The concrete implementation is internal `WalletImpl`. Chain-specific extensions (e.g. `EVMWallet`) add chain-unique methods.

Signer configuration uses a static-factory struct pattern for trailing-closure syntax:

```swift
let wallet = try await CrossmintSDK.shared.wallets.getOrCreate(
    chain: .baseSepolia,
    signer: .email("user@example.com", onAuthRequired: { flow in
        // push flow into @State — closure returns immediately
        // signer suspends internally until flow.verifyOTP() or flow.cancel()
        await MainActor.run { otpFlow = flow }
    })
)
```

`OTPFlow` is a public struct with `sendOTP`, `verifyOTP`, and `cancel` closures. The signer suspends on a `CheckedContinuation` — the closure just delivers the flow object to the UI layer. Add `.crossmintWalletSigner()` to your root view when using email/phone signers.

### TEE Architecture

`TEEProvider` is an internal protocol with swappable implementations: `WebViewTEEProvider` (current, WebView-based), `MockTEEProvider` (tests), and a future `DeviceTEEProvider` (Secure Enclave, no WebView). TEE is an implementation detail of email/phone signers — developers never interact with it directly.

### Auth State

`AuthState` is an actor shared across all modules. `setJWT(_:)` on the singleton stores a developer-supplied token (no refresh). `AuthClient.verifyOTP()` stores both a JWT and refresh token and schedules auto-refresh. HTTP requests pick up the current token via `AuthMiddleware`.

### Error Protocol (Target)

All error types conform to `CrossmintError`:

```swift
public protocol CrossmintError: Error, Sendable {
    var code: String { get }               // SCREAMING_SNAKE_CASE
    var message: String { get }
    var recoverySuggestion: String? { get }
    var underlyingError: Error? { get }
}
```

Domain errors: `WalletError`, `TransactionError`, `AuthError`, `SignerError`, `CheckoutError`.

### Services vs Orchestrators

Services make exactly one API call per method — no orchestration, no polling. Orchestrators coordinate multi-step flows (signer init, create, sign, poll). Simple flows go client → service directly. Reach for an orchestrator only when a flow touches multiple services or requires retry/polling.

### In-Flight Work (as of June 2026)

| Issue | Summary | Status |
|-------|---------|--------|
| WAL-9974 / WAL-10195 / WAL-10196 | Singleton + configure() + setJWT | In Review / Done |
| WAL-10193 | OTPFlow callback pattern | In Review |
| WAL-9977 | Auth client | In Progress |
| WAL-9976 | Move sign/poll out of Wallet | In Progress |
| WAL-10312 | Move onAuthRequired to WalletOptions.Callbacks | Backlog |
| WAL-9978 / WAL-10194 | TEE refactor + TEEProvider protocol | Backlog |
| WAL-9966 | OpenAPI HTTP client generation | Backlog |
| WAL-9979 | Error protocol | Todo |
| WAL-9980 | Logging improvements | Todo |
| WAL-9981 | DocC documentation | Todo (blocked — do last; API not stable) |

## Code Conventions

### Protocol-First Design

Expose behavior through protocols, keep concrete types internal. If the protocol lives in `CrossmintCore`, the implementation lives in the feature module (`CrossmintWalletsImpl`, etc.). External consumers only import protocols and public value types.

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

All new error types must conform to `CrossmintError`. Error codes use `SCREAMING_SNAKE_CASE` (e.g., `WALLET_NOT_FOUND`). Provide a `recoverySuggestion` whenever the developer can take a specific action to fix the problem.

### Complexity Threshold

Before adding background tasks, timers, or retry loops, check whether a simpler pre-call check would suffice, and whether the other SDKs (React Native, Kotlin) do the same thing. Complexity that isn't warranted by the feature and not matched cross-platform creates drift.

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

- **Adding an orchestrator for a single-service flow.** Orchestrators are only warranted when a flow coordinates multiple services or requires retry/polling state. A single API call goes client → service directly.

- **Hardcoding environment or API version strings.** Environment comes from the API key. API versions come from a centralized constant or the OpenAPI generated client.

## Scott's Best Practices

TODO: Scott's best-practices documents were not found in Linear during the WAL-10266 update (searched all workspace documents and filtered by creator). Once located, add a summary here covering naming conventions, function length, comment style, public API discipline, and cross-SDK consistency rules.

## Development Workflow

1. All code must pass SwiftLint checks before merging (`make lint`).
2. Tests run on iPhone 16 Pro simulator by default.
3. The SDK uses Swift Package Manager for dependency management.
4. SwiftLint is integrated as a build tool plugin.
5. Run `/afeight-review` before opening any PR.
6. Run `/sdk-compare` whenever changing or adding anything on the public API surface — the TypeScript SDK (wallets-v1) is the canonical reference.
7. Set these environment variables when running the demo app:
   - `CROSSMINT_API_KEY` — your Crossmint API key
   - `CROSSMINT_WHITELISTED_DOMAIN` — whitelisted domain for the SDK
