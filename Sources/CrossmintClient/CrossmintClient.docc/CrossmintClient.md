# ``CrossmintClient``

Add Crossmint smart wallets and user authentication to your iOS app.

## Overview

Call ``CrossmintSDK/configure(apiKey:logLevel:trackingConsent:)`` once at app startup, then access
``CrossmintSDK/shared`` anywhere. It gives you a ``CrossmintWallets`` factory, a
``CrossmintAuthManager``, and an ``AuthClient`` for explicit OTP lifecycle control.

Wallets are chain-specific: use ``EVMWallet`` for Ethereum-compatible chains and
``SolanaWallet`` for Solana. Email OTP authentication is built-in via ``CrossmintAuthManager``.

## Topics

### Setup

- ``CrossmintSDK``

### Wallets

- ``CrossmintWallets``
- ``Wallet``
- ``EVMWallet``
- ``SolanaWallet``
- ``WalletOptions``
- ``WalletError``

### Signing

- ``SignerConfig``
- ``WalletSigner``
- ``SignerStatus``
- ``TransactionError``
- ``SignatureError``

### Transactions & Transfers

- ``Transaction``
- ``TransactionStatus``
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
- ``AuthClient``
- ``DefaultAuthClient``
- ``OTPRequest``
- ``AuthSession``
- ``AuthUser``
- ``AuthManagerError``
- ``AuthenticationStatus``
- ``OTPAuthenticationStatus``
