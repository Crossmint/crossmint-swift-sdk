# ``CrossmintClient``

Add Crossmint smart wallets and user authentication to your iOS app.

## Overview

The SDK exposes two entry points:

- **``CrossmintSDK``** — includes the built-in email OTP signing flow (TEE) with reactive
  `isOTPRequired` state. Works with SwiftUI, UIKit, or any other framework.
  Call ``CrossmintSDK/shared(apiKey:authManager:logLevel:)`` once at startup.
- **``CrossmintClient``** — a lighter entry point for apps that supply a fully custom
  ``AuthManager`` or do not need the email OTP machinery.
  Call ``CrossmintClient/sdk(key:authManager:)`` and hold the returned ``ClientSDK`` yourself.

Both routes give you a ``CrossmintWallets`` factory and an ``AuthManager``. Wallets are
chain-specific: use ``EVMWallet`` for Ethereum-compatible chains and ``SolanaWallet`` for Solana.
Email OTP authentication is built-in via ``CrossmintAuthManager``.

## Topics

### Setup

- ``CrossmintSDK``
- ``CrossmintClient``
- ``ClientSDK``

### Wallets

- ``CrossmintWallets``
- ``Wallet``
- ``EVMWallet``
- ``SolanaWallet``
- ``WalletOptions``
- ``WalletError``

### Signing

- ``SignerConfig``
- ``TransactionError``
- ``SignatureError``

### Transactions & Transfers

- ``Transaction``
- ``TransactionSummary``
- ``Transfer``
- ``TransferListResult``

### Balances & NFTs

- ``Balance``
- ``Balances``
- ``NFT``

### Authentication

- ``CrossmintAuthManager``
- ``AuthManager``
- ``AuthManagerError``
- ``AuthenticationStatus``
- ``OTPAuthenticationStatus``
