# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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
xcodebuild -scheme CrossmintClientSDK -destination "platform=iOS Simulator,name=iPhone 17 Pro,OS=latest" test
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
CrossmintSDK.configure(apiKey: "ck_staging_...", logLevel: .error, trackingConsent: .granted)

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

@docs/conventions/code.md
@docs/conventions/tests.md

## Development Workflow

1. All code must pass SwiftLint checks before merging (`make lint`).
2. Tests run on iPhone 17 Pro simulator by default.
3. The SDK uses Swift Package Manager for dependency management.
4. SwiftLint is integrated as a build tool plugin.
5. Set these environment variables when running the demo app:
   - `CROSSMINT_API_KEY` — your Crossmint API key
   - `CROSSMINT_WHITELISTED_DOMAIN` — whitelisted domain for the SDK
