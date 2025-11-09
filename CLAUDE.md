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

# Build the Solana demo app
make build-solana-demo
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

The Crossmint Swift SDK is a modular iOS SDK for integrating Crossmint services. The architecture follows a clean separation of concerns with distinct modules for different functionalities.

### Core Modules

1. **CrossmintClient** - Main entry point providing the `ClientSDK` protocol implementation
   - Aggregates all SDK functionality
   - Provides access to wallets, authentication, and services

2. **Wallet** - Smart wallet functionality
   - Generic `Wallet` protocol with specialized implementations (`EVMWallet`, `SolanaWallet`)
   - Supports multiple signer types (EOA, Passkeys)
   - Transaction creation, signing, and management

3. **Auth** - Authentication management
   - OTP-based authentication flow
   - JWT token management
   - Session persistence

4. **Payments** - Payment processing
   - Headless checkout functionality
   - Embedded checkout UI components
   - Multiple payment method support (crypto, card, express checkout)

5. **CrossmintService** - Low-level API communication
   - Request building and execution
   - Error handling
   - Environment configuration

### Supporting Modules

- **CrossmintCommonTypes** - Shared types across modules (blockchains, currencies, etc.)
- **SecureStorage** - Keychain-based secure storage for sensitive data
- **Http** - Network layer abstraction
- **Logger** - Unified logging system
- **Utils** - Common utilities and extensions
- **Passkeys** - Passkey authentication support

### Key Design Patterns

1. **Protocol-Oriented Design**: Most functionality exposed through protocols (`ClientSDK`, `AuthManager`, `CrossmintWallets`, `Wallet`, etc.)

2. **Dependency Injection**: Modules depend on protocol abstractions rather than concrete implementations

3. **Error Handling**: Typed errors using Swift's throwing mechanism with specific error types per module

4. **Async/Await**: Modern Swift concurrency throughout the codebase

5. **SwiftUI Integration**: Provides environment values and view modifiers for easy SwiftUI integration

### Environment Configuration

When running the demo apps, set these environment variables:
- `CROSSMINT_API_KEY` - Your Crossmint API key
- `CROSSMINT_WHITELISTED_DOMAIN` - Whitelisted domain for the SDK

## Test Structure

Tests are organized by module:
- **CrossmintCommonTypesTests** - Tests for common types
- **CrossmintServiceTests** - Service layer tests
- **WalletTests** - Wallet functionality tests
- **PaymentTests** - Payment processing tests
- **UtilsTests** - Utility function tests

Test resources (JSON fixtures) are included in each test target's Resources directory.

## Development Workflow

1. All code must pass SwiftLint checks before merging
2. Tests run on iPhone 16 Pro simulator by default
3. The SDK uses Swift Package Manager for dependency management
4. SwiftLint is integrated as a build tool plugin