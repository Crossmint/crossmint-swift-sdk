# AGENTS.md

This file provides guidance to AI coding agents (Claude Code, Devin, Cursor, and others) when working with code in this repository.

## Best Practices

Before each step of a task, run `"$BP" list`: it prints every topic of the Paella best practices and when it applies. Read the ones that apply with `"$BP" read <topic>...` and follow them. Following a topic means following the topics above it too: `read` prints the root `README.md` and the `README.md` of every directory above the file, and those apply as well.

    BP="${PAELLA_BEST_PRACTICES_DIR:-$HOME/.cache/paella-best-practices}/bin/best-practices.sh"
    [ -x "$BP" ] || { mkdir -p "$(dirname "$BP")" && { gh api -H 'Accept: application/vnd.github.raw' repos/Paella-Labs/best-practices/contents/bin/best-practices.sh > "$BP.$$" 2>/dev/null || { T=$(mktemp -d) && GIT_TERMINAL_PROMPT=0 git clone -q --depth=1 https://github.com/Paella-Labs/best-practices.git "$T" && cp "$T/bin/best-practices.sh" "$BP.$$"; s=$?; rm -rf "$T"; [ "$s" = 0 ]; }; } && [ -s "$BP.$$" ] && bash -n "$BP.$$" && chmod +x "$BP.$$" && mv -f "$BP.$$" "$BP" || rm -f "$BP.$$"; }
    "$BP" list

## Build and Development Commands

### Building the SDK
```bash
make build
```

### Running Tests
```bash
# Run tests with xcodebuild (includes demo app builds)
make test

# Run tests with CI configuration (includes lint check)
make ci-test

# Run specific test target
xcodebuild -scheme CrossmintClientSDK -destination "platform=iOS Simulator,name=iPhone 18 Pro,OS=latest" test
```

### Linting
```bash
make lint

# auto-fix
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
make clean
make resolve
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

Before writing code or tests, read [docs/conventions/code.md](docs/conventions/code.md) and [docs/conventions/tests.md](docs/conventions/tests.md); they hold the full code and test conventions.

## Security

- Never log tokens, passwords, API keys, codes, or personal data (for example email or phone), at any log level. Never put sensitive or personal data in a URL.
- Errors do not expose sensitive data or system details to the caller.
- Store tokens, credentials and personal data in the Keychain, never in `UserDefaults` or plain files. Use the Secure Enclave for keys when available.
- All traffic uses HTTPS with TLS 1.2 or higher.
- Secure by default. Lowering a protection needs an explicit option whose name says what it gives up.
- Prefer CryptoKit and Apple's security frameworks where they support the required algorithm. Use reviewed third-party libraries for EVM secp256k1 signing and Keccak hashing. No custom crypto, no MD5 or SHA-1.
- Prefer Apple frameworks over third-party packages. Every new or bumped dependency needs a reason in the PR, stays on its latest patched version, and is not kept by one person.
- Do not commit secrets, keys or certificates, as files, values or comments. Test fixtures use fake values.
- Treat all data as untrusted, even from Crossmint servers. Validate it before it reaches storage, a WebView, or any other sensitive operation.
- Log security-relevant events (for example failed authentication or a rejected origin) in a format that supports monitoring, without sensitive data.
- Authentication features (biometrics, passkeys) give the host app callbacks for failures and fallbacks.
- Public docs explain how to configure the SDK securely and name the common mistakes.
- Security changes come with tests that try to break the protection, not only tests of the happy path.

## Testing conventions

- New and changed code follows the `code/test` best practices.
- Unit tests: `make test` (xcodebuild, iPhone 18 Pro simulator), `make ci-test` (adds lint), or `xcodebuild -scheme CrossmintClientSDK -destination "platform=iOS Simulator,name=iPhone 18 Pro,OS=latest" test` for one scheme. Naming and structure follow `docs/conventions/tests.md`.
- E2E: comment `/e2e` (optionally `/e2e ios` or `/e2e android`) on a PR to dispatch the shared mobile suite in `Crossmint/crossmint-mobile-e2e-tests`.

## Development Workflow

1. All code must pass SwiftLint checks before merging (`make lint`).
2. Tests run on iPhone 18 Pro simulator by default.
3. The SDK uses Swift Package Manager for dependency management.
4. SwiftLint is integrated as a build tool plugin.
5. Set these environment variables when running the demo app:
   - `CROSSMINT_API_KEY` — your Crossmint API key
   - `CROSSMINT_WHITELISTED_DOMAIN` — whitelisted domain for the SDK
