# Crossmint Mobile SDK — Master Test Plan
> Swift · Kotlin · Flutter
> Environment: **staging.crossmint.com**
> Created: 2026-04-09

---

## 0. Environment & Credentials

| Setting | Value |
|---------|-------|
| Base URL | `https://staging.crossmint.com` |
| API Key | `sk_staging_9pExrhkpRzgB5ErA4CrQYHUADNTbFurnK1FE8magkFikzbmMKmKL8oUrKXJ8UiHzQTwkHuFR4kFDVraXmd3rvus7Z3ZhSakZYUGYQL21nNdWpV2kQENFTanQA495yKhWvSHwCncFmUNaqU3KP2QHdWgKmszQ8XjcAfoXUKJDm3aq4urvmLbGxB2vs9GCH11bYMn4JGL7oV7QQEztFY4oJwWg` |
| Primary EVM chain | `base-sepolia` |
| Secondary EVM chain | `ethereum-sepolia` |
| Solana | `solana` (devnet via staging) |
| Stellar | `stellar` (testnet via staging) |
| Test email | `crossmint-sdk-test+{uuid}@yopmail.com` (unique per run) |

### How to Run

| SDK | Command |
|-----|---------|
| Swift | `xcodebuild test -scheme CrossmintClientSDK -destination "platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2" -testPlan CrossmintSDK -only-testing CrossmintClientTests -skipPackagePluginValidation` |
| Kotlin | `./gradlew jvmTest` or `make test-jvm` |
| Flutter | `flutter test` |

### Existing Test Locations

| SDK | Test Folder |
|-----|------------|
| Swift | `Tests/` — 37 files, 5,746 LOC |
| Kotlin | `sdk-*/src/commonTest/` — 31 files |
| Flutter | `test/` — 31 files |

---

## 1. SDK Initialization

### 1.1 Happy Path

| ID | Scenario | Swift | Kotlin | Flutter |
|----|----------|-------|--------|---------|
| INIT-01 | Initialize with valid staging API key | `CrossmintSDK.shared(apiKey:)` | `Crossmint.shared(apiKey, context)` | `CrossmintClient(config:)` + `initialize()` |
| INIT-02 | Access `.crossmintWallets` after init | `sdk.crossmintWallets` | `sdk.crossmintWallets` | `client.wallets` |
| INIT-03 | Access `.authManager` after init | `sdk.authManager` | `sdk.authManager` | `client.auth` |
| INIT-04 | Singleton returns same instance | Call `shared` twice — same object | `Crossmint.instance` | `client` reference stable |

### 1.2 Error / Edge Cases

| ID | Scenario | Expected |
|----|----------|----------|
| INIT-05 | Empty API key string | `ApiKeyError.MalformedKey` / exception |
| INIT-06 | API key with wrong prefix (not `sk_staging_`) | `ApiKeyError.InvalidEnvironmentKey` / error |
| INIT-07 | Old format API key | `ApiKeyError.OldKey` error |
| INIT-08 | Call wallet operations before `initialize()` | `ServiceNotInitialized` error |
| INIT-09 | Call `initialize()` twice (idempotency) — Flutter only | Second call is no-op, no crash |
| INIT-10 | Dispose client and re-initialize — Flutter only | Fresh state, no leaked references |

---

## 2. Authentication

### 2.1 Email OTP — Happy Path

| ID | Scenario | Swift | Kotlin | Flutter |
|----|----------|-------|--------|---------|
| AUTH-01 | Send OTP to valid email | `otpAuthentication(email:)` → `.emailSent` | `sendOtp(email)` → `CODE_SENT` | `auth.sendEmailOtp(email)` |
| AUTH-02 | Verify correct OTP code | `otpAuthentication(email:code:)` → `.authenticated` | `verifyOtp(email, code)` → `AUTHENTICATED` | `auth.confirmEmailOtp(email, emailId, code)` |
| AUTH-03 | Get JWT after authentication | `authManager.jwt` non-nil | `authManager.getJWT()` non-null | `client.auth.state.jwt` non-null |
| AUTH-04 | JWT is refreshed before expiry | Wait until 90% lifetime passes, verify new JWT | Same — auto-refresh via coroutine | `auth.restoreSession()` returns valid session |
| AUTH-05 | Logout clears session | `logout()` → `jwt` is nil | `logout()` → `authState.isAuthenticated = false` | `auth.state.jwt == null` |

### 2.2 Authentication — Error Cases

| ID | Scenario | Expected |
|----|----------|----------|
| AUTH-06 | Send OTP to malformed email (no @) | Validation error before API call |
| AUTH-07 | Send OTP to empty string | Error, no API call |
| AUTH-08 | Verify OTP with wrong code | `InvalidCredentials` / 401 error |
| AUTH-09 | Verify OTP with expired code | Server returns error |
| AUTH-10 | Verify OTP with empty code string | Validation error |
| AUTH-11 | Get JWT before login | `nil` / `null` / empty |
| AUTH-12 | Submit OTP when no signing operation is pending | No-op or error |
| AUTH-13 | Call `logout()` when not authenticated | No crash, state remains unauthenticated |
| AUTH-14 | Use expired JWT for wallet operation | `TokenExpired` or `Unauthorized` error |

### 2.3 Authentication — Edge Cases

| ID | Scenario | Expected |
|----|----------|----------|
| AUTH-15 | Send OTP twice to same email rapidly (rate limit) | `RateLimited` or server error on second call |
| AUTH-16 | Email with special characters (`+`, `.`, uppercase) | Normalisation and successful auth |
| AUTH-17 | Very long email (>254 chars) | Validation or server error |
| AUTH-18 | Phone number auth (Kotlin + Flutter) | Same flow as email, different endpoint |
| AUTH-19 | Direct token auth — Kotlin only (`authenticateWithToken`) | Sets authState as authenticated |

### 2.4 Flutter-Only Auth

| ID | Scenario | Expected |
|----|----------|----------|
| AUTH-20 | OAuth Google login start — `loginWithOAuth('google')` | Returns OAuth URL, no crash |
| AUTH-21 | OAuth Twitter login start | Returns OAuth URL |
| AUTH-22 | `restoreSession()` with stored JWT | Returns previously saved session |
| AUTH-23 | `restoreSession()` with no stored session | Returns unauthenticated state gracefully |
| AUTH-24 | `signInWithWallet()` | Returns challenge message to sign |

---

## 3. Wallet Creation

### 3.1 Happy Path

| ID | Scenario | Chain | Signer | Expected |
|----|----------|-------|--------|----------|
| WC-01 | Create EVM wallet with email signer | `base-sepolia` | `email` | Returns wallet with valid address |
| WC-02 | Create EVM wallet with API key signer | `base-sepolia` | `api-key` | Returns wallet with valid address |
| WC-03 | Create EVM wallet with device signer | `base-sepolia` | `device` | Returns wallet; device key stored locally |
| WC-04 | Create Solana wallet with email signer | `solana` | `email` | Returns wallet with valid Base58 address |
| WC-05 | Create Solana wallet with API key signer | `solana` | `api-key` | Returns wallet with valid address |
| WC-06 | Create Stellar wallet with email signer | `stellar` | `email` | Returns wallet with valid Stellar address (G...) |
| WC-07 | Create Stellar wallet with API key signer | `stellar` | `api-key` | Returns wallet with valid address |
| WC-08 | Create wallet with alias | any | any | `wallet.alias == suppliedAlias` |
| WC-09 | Create wallet with owner email | any | any | `wallet.owner.email == suppliedEmail` |
| WC-10 | Create wallet idempotently (same key twice) | any | any | Same wallet returned, no duplicate |
| WC-11 | Create wallet then `getWallet` returns same | any | any | Same address |
| WC-12 | Create EVM wallet on `ethereum-sepolia` | `ethereum-sepolia` | `api-key` | Different chain, valid address |

### 3.2 Creation — Error Cases

| ID | Scenario | Expected |
|----|----------|----------|
| WC-13 | Create wallet with unsupported chain string | `ChainNotSupported` or 400 error |
| WC-14 | Create wallet with empty chain string | Validation error |
| WC-15 | Create wallet without authentication (no JWT) | `Unauthorized` (401) |
| WC-16 | Create wallet with invalid signer type | 400 or `InvalidInput` error |
| WC-17 | Create wallet with invalid email format for signer | Validation error |
| WC-18 | Create wallet with null/empty recovery signer — Swift/Flutter | `WalletError` or validation error |
| WC-19 | Create with API key on testnet chain but production key | `InvalidEnvironmentKey` error |

### 3.3 Creation — Edge Cases

| ID | Scenario | Expected |
|----|----------|----------|
| WC-20 | Create multiple wallets for same user (different chains) | All succeed, distinct addresses |
| WC-21 | Create wallet with alias containing special characters | Succeeds or specific validation error |
| WC-22 | Create wallet with empty alias string | Succeeds (alias omitted) or error |
| WC-23 | Create wallet with very long alias (>255 chars) | Validation or server error |
| WC-24 | Create wallet with both device signer and email signer | Depends on SDK support — check behavior |
| WC-25 | Create Solana wallet with device signer (unsupported per Flutter gist) | Flutter: explicit error; Kotlin/Swift: documented behavior |

---

## 4. Wallet Retrieval (`getWallet`)

| ID | Scenario | Expected |
|----|----------|----------|
| GW-01 | Get existing EVM wallet | Returns wallet with correct address |
| GW-02 | Get existing Solana wallet | Returns wallet with correct address |
| GW-03 | Get existing Stellar wallet | Returns wallet with correct address |
| GW-04 | Get wallet that doesn't exist | Swift: returns `nil`; Kotlin: `WalletNotFound`; Flutter: null |
| GW-05 | Get wallet without authentication | `Unauthorized` (401) |
| GW-06 | Get wallet with wrong chain for existing wallet | `WalletNotFound` / null |
| GW-07 | Get wallet returns config (signers, admin) | `wallet.config.adminSigner` populated |
| GW-08 | Get wallet after creation — consistency check | Same address as created |
| GW-09 | Get wallet by locator (email:, userId:) — Flutter | Correct wallet resolved |

---

## 5. Balances

### 5.1 Happy Path

| ID | Scenario | Chain | Expected |
|----|----------|-------|----------|
| BAL-01 | Get native token balance (ETH) on EVM | `base-sepolia` | Returns numeric balance ≥ 0 |
| BAL-02 | Get USDC balance on EVM | `base-sepolia` | Returns numeric balance ≥ 0 |
| BAL-03 | Get native SOL balance | `solana` | Returns numeric balance ≥ 0 |
| BAL-04 | Get USDC balance on Solana | `solana` | Returns numeric balance |
| BAL-05 | Get XLM native balance on Stellar | `stellar` | Returns numeric balance ≥ 0 |
| BAL-06 | Get USDXM balance on Stellar | `stellar` | Returns numeric balance |
| BAL-07 | Get all balances (no filter) | any | Returns all available tokens |
| BAL-08 | Get specific token list | any | Returns only requested tokens |
| BAL-09 | Fund wallet then verify balance increases | `base-sepolia` | Balance reflects funded amount |
| BAL-10 | Balance response includes `rawAmount` and `decimals` | any | Kotlin: present in model |

### 5.2 Balances — Error Cases

| ID | Scenario | Expected |
|----|----------|----------|
| BAL-11 | Get balance without authentication | `Unauthorized` (401) |
| BAL-12 | Get balance with invalid token locator | Server error or empty result |
| BAL-13 | Get balance on wrong chain | `WalletNotFound` or empty result |
| BAL-14 | Get balance for token that doesn't exist on chain | Zero balance or empty entry |

---

## 6. Fund (Staging Only)

> **Swift finding (2026-04-10):** The Crossmint staging API only supports `.usdxm` for wallet funding via `wallet.fund(token:amount:)`. Requests with `.eth` or `.usdc` return `walletGeneric("token: Only USDXM is supported for funding wallets")`. Tests FUND-01/02 have been updated accordingly.

| ID | Scenario | Chain | Expected |
|----|----------|-------|----------|
| FUND-01 | Fund EVM wallet with USDXM (staging only supported token) | `base-sepolia` | No error thrown |
| FUND-02 | Fund EVM wallet with unsupported token (e.g. ETH) | `base-sepolia` | `walletGeneric` error mentioning USDXM |
| FUND-03 | Fund Solana wallet with SOL | `solana` | SOL balance increases |
| FUND-04 | Fund Solana wallet with USDC | `solana` | USDC balance increases |
| FUND-05 | Fund Stellar wallet with XLM | `stellar` | XLM balance increases |
| FUND-06 | Fund with zero amount | Error or no-op |
| FUND-07 | Fund with negative amount | Validation error |
| FUND-08 | Fund with very large amount (>staging limit) | Server error or capped |
| FUND-09 | Fund production wallet (should be rejected) | Error if env check enforced |

---

## 7. Token Transfers (`send`)

### 7.1 Happy Path — Prerequisites: fund wallet first

| ID | Scenario | Chain | Token | Expected |
|----|----------|-------|-------|----------|
| SEND-01 | Send ETH to external address | `base-sepolia` | `eth` | Transaction created, status success |
| SEND-02 | Send USDC to external address | `base-sepolia` | `usdc` | Transaction success, balance decreases |
| SEND-03 | Send ETH to another Crossmint wallet (email: locator) | `base-sepolia` | `eth` | Resolves recipient, tx success |
| SEND-04 | Send SOL to external address | `solana` | `sol` | Transaction success |
| SEND-05 | Send USDC on Solana | `solana` | `usdc` | Transaction success |
| SEND-06 | Send XLM on Stellar | `stellar` | `xlm` | Transaction success |
| SEND-07 | Send USDXM on Stellar | `stellar` | `usdxm` | Transaction success |
| SEND-08 | Send with idempotency key | any | any | Same tx returned on retry |
| SEND-09 | Send with specific signer selection | any | any | Uses specified signer |

### 7.2 Transfers — Error Cases

| ID | Scenario | Expected |
|----|----------|----------|
| SEND-10 | Send with insufficient balance | `TransactionFailed` / server error |
| SEND-11 | Send to invalid address (bad checksum EVM) | Validation or server error |
| SEND-12 | Send to empty string address | Validation error |
| SEND-13 | Send zero amount | Validation or server error |
| SEND-14 | Send negative amount | Validation error |
| SEND-15 | Send with invalid token locator | Server 400 error |
| SEND-16 | Send to Solana address on EVM chain | Server error or validation |
| SEND-17 | Send to non-existent email locator | Server error |
| SEND-18 | Send without authentication | `Unauthorized` (401) |
| SEND-19 | Send to own address | Succeeds (self-transfer) or specific error |

### 7.3 Transfers — Edge Cases

| ID | Scenario | Expected |
|----|----------|----------|
| SEND-20 | Send very small amount (0.000001) | Succeeds or dust limit error |
| SEND-21 | Send max available balance | Succeeds minus fees |
| SEND-22 | Duplicate send with same idempotency key | Returns original transaction (idempotent) |
| SEND-23 | Send with different idempotency keys for same params | Two distinct transactions |
| SEND-24 | Concurrent sends (two parallel calls) | Both succeed or conflict handled |

---

## 8. Transaction Approval (`approve`)

| ID | Scenario | Expected |
|----|----------|----------|
| APPR-01 | Approve a pending transaction | Status changes to `success` |
| APPR-02 | Approve transaction that is already approved | Error or idempotent success |
| APPR-03 | Approve transaction with wrong signer | `Unauthorized` or `Forbidden` |
| APPR-04 | Approve non-existent transaction ID | `TransactionNotFound` (404) |
| APPR-05 | Approve empty transaction ID | Validation error |
| APPR-06 | Approve failed transaction | Error (cannot approve failed) |
| APPR-07 | Approve transaction on wrong chain | `TransactionNotFound` |
| APPR-08 | `getTransaction(id)` returns correct status — Kotlin | `AWAITING_APPROVAL` → `SUCCESS` after approve |

---

## 9. Signer Management

### 9.1 Add Signer — Happy Path

| ID | Scenario | Chain | Signer Type | Expected |
|----|----------|-------|-------------|----------|
| SGN-01 | Add email delegated signer to EVM wallet | `base-sepolia` | `email` | Signer appears in wallet config |
| SGN-02 | Add email delegated signer to Solana wallet | `solana` | `email` | Signer registered |
| SGN-03 | Add email delegated signer to Stellar wallet | `stellar` | `email` | Signer registered |
| SGN-04 | Add device signer to EVM wallet | `base-sepolia` | `device` | Device key stored, signer registered |
| SGN-05 | Add external wallet signer | `base-sepolia` | `external-wallet` | Signer registered |
| SGN-06 | `signerIsRegistered(locator)` returns true after add | any | any | `true` |
| SGN-07 | Swift: `addSigner` + `useSigner` then send | any | any | Transaction uses new signer |

### 9.2 Remove Signer — Happy Path (Swift + Flutter)

| ID | Scenario | Expected |
|----|----------|----------|
| SGN-08 | Remove existing delegated signer | Transaction created for removal, signer gone after confirm |
| SGN-09 | `signerIsRegistered(locator)` returns false after remove | `false` |

### 9.3 Signer — Error Cases

| ID | Scenario | Expected |
|----|----------|----------|
| SGN-10 | Add signer that already exists | `409 Conflict` or idempotent |
| SGN-11 | Add invalid signer locator format | Validation or 400 error |
| SGN-12 | Add empty signer locator | Validation error |
| SGN-13 | Remove non-existent signer | `404` or `SignerNotRegistered` |
| SGN-14 | Remove admin/recovery signer | `400 Bad Request` (cannot remove admin) |
| SGN-15 | Add signer without authentication | `Unauthorized` |
| SGN-16 | Add device signer to Solana (unsupported) | Flutter: explicit error; check Swift/Kotlin behavior |

### 9.4 Recovery

| ID | Scenario | Expected |
|----|----------|----------|
| SGN-17 | `needsRecovery()` returns false for fresh wallet | `false` |
| SGN-18 | Swift `recover()` re-registers device signer | Device signer back in wallet |
| SGN-19 | Flutter `runtimeWallet.needsRecovery` | Correct value |

---

## 10. TEE / Non-Custodial Signing

| ID | Scenario | Expected |
|----|----------|----------|
| TEE-01 | TEE handshake completes successfully | State: `.completed` / ready |
| TEE-02 | TEE handshake times out | State: `.failed`, retried 3× then error |
| TEE-03 | OTP required: `isOTPRequired` emits `true` | OTP prompt shown |
| TEE-04 | Submit correct OTP | Signing proceeds |
| TEE-05 | Submit wrong OTP | Error returned |
| TEE-06 | Cancel transaction during OTP wait | `cancelTransaction()` aborts cleanly |
| TEE-07 | Reset state clears WebView | No stale state after `resetState()` |
| TEE-08 | TEE signs transaction and `approve()` proceeds | Transaction completes on-chain |

---

## 11. NFTs (Swift-only)

| ID | Scenario | Expected |
|----|----------|----------|
| NFT-01 | Get NFTs — empty wallet | Returns empty list (not error) |
| NFT-02 | Get NFTs with page 1, perPage 10 | Returns up to 10 NFTs |
| NFT-03 | Paginate NFTs (page 2) | Returns next page or empty |
| NFT-04 | Get NFTs with invalid page (0 or -1) | Validation error |
| NFT-05 | Get NFTs without authentication | `Unauthorized` |
| NFT-06 | Flutter: NFT listing via `runtimeWallet.nfts()` | Returns list or empty |

---

## 12. Transfer History

> **Swift finding (2026-04-10):** `wallet.listTransfers(tokens: [])` (empty array) is rejected by the Crossmint API on Solana with `walletGeneric("tokens: tokens is required")`. Always pass at least one token (e.g. `[.usdc]`) for Solana. EVM behaves the same way (pass `[.eth]` at minimum).

| ID | Scenario | SDK | Expected |
|----|----------|-----|----------|
| HIST-01 | `listTransfers` returns history after send | Swift, Flutter | Non-empty list |
| HIST-02 | `listTransfers` on fresh wallet | Swift, Flutter | Empty list |
| HIST-03 | `listTransfers` filters by token | Swift | Only matching transfers returned |
| HIST-04 | `experimental_transactions()` — Swift equivalent | Swift | Returns list of transactions |
| HIST-05 | `listTransfers` without authentication | Swift, Flutter | `Unauthorized` |
| HIST-06 | Flutter `runtimeWallet.transactions()` | Flutter | Returns paginated history |
| HIST-07 | Flutter `runtimeWallet.transaction(id)` | Flutter | Returns single transaction |

---

## 13. Headless Client APIs (Flutter-Only)

| ID | Scenario | Expected |
|----|----------|----------|
| HC-01 | `client.orders.getOrder(orderId)` | Returns order or 404 |
| HC-02 | `client.tokens.listTokens()` | Returns token list |
| HC-03 | `client.users.getUser()` | Returns authenticated user |
| HC-04 | `client.credentials` — issue verifiable credential | Returns VC or error |
| HC-05 | `client.orders` — unauthenticated | `Unauthorized` |
| HC-06 | `CrossmintEmbeddedCheckout` widget renders | No crash, checkout shown |

---

## 14. Input Validation (All SDKs)

| ID | Parameter | Invalid Values to Test | Expected |
|----|-----------|----------------------|----------|
| VAL-01 | API Key | `""`, `"not_a_key"`, `"sk_production_..."` | Error at init |
| VAL-02 | Chain | `""`, `"bitcoin"`, `"SOLANA"` (wrong case for APIs), `"unknown"` | `ChainNotSupported` |
| VAL-03 | Email | `""`, `"notanemail"`, `"@no-local"`, `"a@b"` | Validation error |
| VAL-04 | Recipient Address EVM | `""`, `"0x"`, `"0xZZZZ"`, correct-length wrong checksum | Error |
| VAL-05 | Recipient Address Solana | `""`, too-short base58, EVM address | Error |
| VAL-06 | Recipient Address Stellar | `""`, `"Gfake"`, EVM address | Error |
| VAL-07 | Amount | `0`, `-1`, `""`, `NaN`, `Infinity` | Validation error |
| VAL-08 | Token locator | `""`, `"nochain"`, `":"`, `"chain:"` | Error |
| VAL-09 | Transaction ID | `""`, `"not-a-uuid"`, random string | `TransactionNotFound` or validation |
| VAL-10 | Idempotency key | `""`, 500-char string | Behavior documented |
| VAL-11 | Signer locator | `""`, `":"`, `"invalid:format:"` | Error |

---

## 15. Error Mapping (All SDKs)

Verify each HTTP status code maps to the correct SDK error type:

| HTTP Status | Kotlin Error | Swift Error | Flutter Exception |
|------------|-------------|-------------|-------------------|
| 400 | `WalletError.InvalidInput` | `WalletError` | `CrossmintException(code: badRequest)` |
| 401 | `WalletError.Unauthorized` | `WalletError` | `CrossmintException(code: unauthorized)` |
| 403 | `WalletError.Forbidden` | `WalletError` | `CrossmintException(code: forbidden)` |
| 404 | `WalletError.WalletNotFound` | `WalletError` (nil for getWallet) | `CrossmintException(code: notFound)` |
| 409 | `WalletError.WalletOperationFailed` | `WalletError` | `CrossmintException(code: conflict)` |
| 422 | `TransactionError.TransactionCreationFailed` | `TransactionError` | `CrossmintException` |
| 429 | `WalletError.RateLimited` | `WalletError` | `CrossmintException(code: rateLimited)` |
| 500 | `NetworkError.HttpError` | `WalletError` | `CrossmintException(code: serverError)` |
| 502–504 | `NetworkError.HttpError` | `WalletError` | `CrossmintException(code: serverError)` |
| Timeout | `NetworkError.TimeoutError` | `WalletError` | `CrossmintException(code: timeout)` |
| No network | `NetworkError.ConnectionError` | `WalletError` | Network exception |

---

## 16. Cross-SDK Parity Tests

These verify identical behaviour across all three SDKs for the same operation:

| ID | Operation | What to verify |
|----|-----------|---------------|
| PARITY-01 | Create EVM wallet, email signer | Same API endpoint called, same wallet address structure |
| PARITY-02 | Get wallet — existing | Same response fields available |
| PARITY-03 | Fund + check balance | Balance model has same fields: `symbol`, `amount`, `rawAmount`, `decimals` |
| PARITY-04 | Send token flow | Same poll-until-success pattern, same transaction status lifecycle |
| PARITY-05 | Error on 401 | All three surface an "unauthorized" type error |
| PARITY-06 | Error on 404 wallet not found | Swift nil, Kotlin WalletNotFound, Flutter null/exception |
| PARITY-07 | `getDeviceSignerSecurityLevel` / device key check | Kotlin has full API; Swift: SecureEnclave vs Keychain; Flutter: plugin level |
| PARITY-08 | Add delegated signer | All three call same `/signers` endpoint |
| PARITY-09 | Transaction status lifecycle: `awaiting-approval` → `success` | All SDKs poll and expose each state |

---

## 17. Exploratory / Break Tests

These are open-ended tests meant to find unexpected failures:

| ID | Scenario |
|----|----------|
| EXP-01 | Hammer `getWallet` 20× concurrently — no crash, consistent result |
| EXP-02 | Create 5 wallets sequentially — no state pollution |
| EXP-03 | Switch chains rapidly in calls — no state leakage |
| EXP-04 | Send while send is in-flight (concurrent double-send) |
| EXP-05 | Kill and restart app mid-transaction — state recovers |
| EXP-06 | Use a wallet address from another user's account — `Forbidden` |
| EXP-07 | Inject SQL-like strings in email / alias fields |
| EXP-08 | Inject `<script>` in string fields |
| EXP-09 | Use extremely long strings (1000+ chars) in every string param |
| EXP-10 | Unicode / emoji in email, alias, OTP code |
| EXP-11 | Replay old JWT (simulate stolen token after logout) — server rejects |
| EXP-12 | Network interrupt mid-request — SDK handles gracefully, no crash |
| EXP-13 | Call all methods on a disposed/cleared client — clean error, no crash |
| EXP-14 | Use a wallet address as the recipient for its own transfer |
| EXP-15 | Send to EVM null address `0x0000000000000000000000000000000000000000` |

---

## 18. SDK-Specific Additional Tests

### Swift Only
| ID | Scenario |
|----|----------|
| SW-01 | `EVMWallet.sendTransaction(to:value:data:chain:)` with raw calldata |
| SW-02 | `EVMWallet.sendTransaction` with `prepareOnly = true` — no signing |
| SW-03 | `SolanaWallet.sendTransaction(transaction:)` with base58 serialized tx |
| SW-04 | `wallet.nfts(page:nftsPerPage:)` pagination |
| SW-05 | Passkey signer creation and signing (ASN.1 signature parsing) |
| SW-06 | `SecureEnclaveKeyStorage` vs `KeychainDeviceSignerKeyStorage` fallback |
| SW-07 | SwiftUI `crossmintNonCustodialSigner` view modifier renders without crash |
| SW-08 | `WalletLocator` parses all formats: `address:`, `email:`, `userId:`, `phoneNumber:`, `twitter:` |
| SW-09 | `CryptoCurrency.unknown("customToken")` passed to balances |
| SW-10 | Test all 66 supported EVM chain enum values parse without crash |

### Kotlin Only
| ID | Scenario |
|----|----------|
| KT-01 | `CrossmintSDK.createNoOpInstance()` — all operations return no-ops |
| KT-02 | `sdk.isStaging` returns `true` for staging API key |
| KT-03 | `sdk.isOTPRequired` Flow emits `true` then `false` after OTP submit |
| KT-04 | `sdk.cancelTransaction()` aborts in-flight TEE operation |
| KT-05 | `wallet.fund(token, amount, chain)` — staging test only |
| KT-06 | `wallet.setSigner(signer)` then `send()` uses new signer |
| KT-07 | `wallet.getTransaction(id)` returns all status values |
| KT-08 | `TinkWithFallbackSessionStore` encrypts and persists tokens |
| KT-09 | `AuthSessionStore` (in-memory) clears on logout |
| KT-10 | `WalletType.SMART_WALLET` vs `MPC_WALLET` distinction |
| KT-11 | `DelegatedSigner.Passkey(id, name, publicKeyX, publicKeyY)` — EVM only |
| KT-12 | JVM tests run without Android context (`CrossmintSDK` in server mode) |

### Flutter Only
| ID | Scenario |
|----|----------|
| FL-01 | `CrossmintWalletController` lifecycle: `loadWallet()` → `createWallet()` → `clear()` |
| FL-02 | `walletController.status` changes: `idle → loading → ready` |
| FL-03 | OTP challenge: `otpChallengeListenable` fires on `sendOtp` |
| FL-04 | `walletController.rejectOtp()` clears OTP challenge |
| FL-05 | `runtimeWallet.exportPrivateKey()` — exportable signer only |
| FL-06 | `CrossmintWalletHost` widget mounts without crash |
| FL-07 | `CrossmintAuthForm` widget shows email & OAuth buttons |
| FL-08 | `CrossmintEmailOtpDialog` shows OTP input fields |
| FL-09 | `CrossmintNftCard` renders with mock NFT data |
| FL-10 | `CrossmintEmbeddedCheckout` renders with valid config |
| FL-11 | `client.credentials` — verifiable credential issue & verify |
| FL-12 | `CrossmintAuthCallbackRouter.start()` handles OAuth callback URI |
| FL-13 | Device signer NOT supported for Solana — verify correct error |
| FL-14 | Passkey signer requires explicit callbacks — verify error when missing |
| FL-15 | External wallet signer requires `signCallback` — verify error when nil |
| FL-16 | `CrossmintChain.fromApiValue('base-sepolia')` parses correctly |
| FL-17 | `CrossmintChain.validateForEnvironment()` — staging chain vs production |

---

## 19. Token & Chain Matrix

Test the following token × chain combinations with `balances()` and `send()`:

| Chain | Native | USDC | USDC-E | Other |
|-------|--------|------|--------|-------|
| `base-sepolia` (EVM) | `eth` | `usdc` | — | — |
| `ethereum-sepolia` (EVM) | `eth` | `usdc` | — | — |
| `solana` | `sol` | `usdc` | — | `bonk`, `wif` |
| `stellar` | `xlm` | `usdc` | — | `usdxm` |

For each cell: verify balance returns, verify send succeeds (after fund), verify error on insufficient balance.

---

## 20. Test Execution Order & Dependencies

```
1. INIT tests           → prerequisite for all others
2. AUTH tests           → prerequisite for wallet operations
3. WC (wallet create)   → prerequisite for most other tests
4. FUND tests           → prerequisite for SEND tests
5. BAL tests            → run after FUND
6. SEND tests           → run after FUND + BAL
7. APPR tests           → depends on SEND creating pending txs
8. SGN tests            → can run after WC
9. TEE tests            → depends on non-custodial signer
10. NFT tests           → independent, needs wallet
11. HIST tests          → run after SEND
12. Parity tests        → run across all SDKs in parallel
13. Exploratory tests   → run last
```

---

## 21. Test Data

```
Staging email (OTP): crossmint-sdk-test+{unique}@yopmail.com
EVM recipient:       0x1234567890123456789012345678901234567890
Solana recipient:    3BzWtPvNkfkr9TXrR3YBhNFxMmF3gjtWw7SWvFGc9Hbq
Stellar recipient:   GAAZI4TCR3TY5OJHCTJC2A4QSY6CJWJH5IAJTGKIN2ER7LBNVKOCCWN
Invalid EVM addr:    0xdeadbeef
Invalid amount:      -1, 0, "abc", null
Token locators:
  base-sepolia:eth, base-sepolia:usdc
  solana:sol, solana:usdc
  stellar:xlm, stellar:usdxm
```

---

## 22. Reporting Template

For each test case record:

```
ID:          [test ID]
SDK:         Swift | Kotlin | Flutter
Status:      PASS | FAIL | SKIP | BLOCKED
Actual:      [what actually happened]
Expected:    [what should have happened]
Bug:         Test bug | SDK bug | API bug | Infra
Notes:       [any additional context]
```

---

## 23. Swift SDK Implementation Findings (2026-04-10)

These are confirmed behaviors discovered while implementing the Swift test suite (`CrossmintClientTests`). 69 tests pass (53 unit + 16 staging integration).

> **Shared variables used in all curl examples below**
> ```bash
> BASE="https://staging.crossmint.com/api"
> SK_KEY="sk_staging_..."   # server key — for api-key signer wallets
> CK_KEY="ck_staging_..."   # client key — for email/passkey signer wallets
> JWT="<bearer-token>"      # obtained after OTP auth (see AUTH-01/02 curl below)
> WALLET_ADDR="0x..."       # EVM wallet address returned by createWallet
> EMAIL="user@example.com"
> EMAIL_ID="<state-from-validateEmail-response>"
> ```

---

### §A — SDK Bugs / Unexpected Behavior

---

#### SW-BUG-01 · `ApiKeySignerData.locatorId` hardcoded — server address discarded

**Files**: `AdminSignerData.swift:66`, `ApiKeySignerApiModel.swift:9`

`ApiKeySignerData.locatorId` always returns the string literal `"api-key"`, so the computed `locator` is always `"api-key:api-key"`. When the wallet is fetched, `ApiKeySignerApiModel.toDomain` calls `ApiKeySignerData()` and silently discards the real `locator` field from the server JSON (e.g. `"api-key:0x742d35Cc..."`).

**Step 1** — create a wallet with an api-key admin signer (requires `sk_` server key):
```bash
curl -s -X POST "$BASE/2025-06-09/wallets/me" \
  -H "X-API-KEY: $SK_KEY" \
  -H "Content-Type: application/json" \
  -d '{"chainType":"evm","type":"smart","config":{"adminSigner":{"type":"api-key"}}}'
```

**Step 2** — fetch the wallet and observe the real locator:
```bash
curl -s "$BASE/2025-06-09/wallets/me:evm" \
  -H "X-API-KEY: $SK_KEY"
# Server response contains:
# "adminSigner": {"type":"api-key","locator":"api-key:0x742d35Cc...","address":"0x742d35Cc..."}
```

**Step 3** — SDK converts this to `ApiKeySignerData()` → `locator = "api-key:api-key"`:
```swift
// serverLocator is what the API returns in step 2
let serverLocator = "api-key:0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb"
let sdkLocator    = "api-key:api-key"  // hardcoded by ApiKeySignerData.locatorId

await wallet.signerIsRegistered(serverLocator)  // → false  ← BUG (should be true)
await wallet.signerIsRegistered(sdkLocator)     // → true
```

**Impact**: `signerIsRegistered` never matches the real server locator; only `"api-key:api-key"` works.

---

#### SW-BUG-02 · No local email format validation before OTP send

**File**: `CrossmintAuth/DefaultAuthManager.swift` — `otpAuthentication(email:)`

The method passes the email string directly to the network layer without any format check. Invalid emails reach the server.

**Reproduce** — send a malformed email; error comes from the server, not locally:
```bash
curl -s -X POST "$BASE/2024-09-26/session/sdk/auth/otps/send" \
  -H "X-API-KEY: $CK_KEY" \
  -H "Content-Type: application/json" \
  -d '{"email": "notanemail"}'
# Server returns 400: {"message":"email must be an email"}
# SDK wraps as: AuthManagerError.serviceError("email must be an email")
```

```swift
do {
    _ = try await authManager.otpAuthentication(email: "notanemail")
    // Expected: local throw for malformed email
    // Actual:   network call is made; server 400 is rethrown as serviceError
} catch AuthManagerError.serviceError(let msg) {
    print(msg) // "email must be an email" — server-side message
}
```

**Impact**: AUTH-06 (`"notanemail"`), AUTH-07 (`""`) and AUTH-17 (254+ char email) cannot be unit-tested locally; they always hit the network.

---

#### SW-BUG-03 · Empty OTP code forwarded to server without local validation

**File**: `CrossmintAuth/DefaultAuthManager.swift` — `otpAuthentication(email:code:)`

An empty `code` string is not rejected locally; it is forwarded as `token=` in the query string.

**Reproduce** — submit an empty OTP token:
```bash
curl -s -X POST \
  "$BASE/2024-09-26/session/sdk/auth/authenticate\
?signinAuthenticationMethod=email\
&email=$EMAIL\
&token=\
&state=$EMAIL_ID\
&callbackUrl=$BASE/2024-09-26/session/sdk/auth/authenticate/callback" \
  -H "X-API-KEY: $CK_KEY"
# Server returns an error — no local validation fires first
```

```swift
// Step 1 — trigger OTP send (stores emailID internally)
_ = try await authManager.otpAuthentication(email: "user@example.com")

// Step 2 — empty code is not rejected locally
do {
    _ = try await authManager.otpAuthentication(email: "user@example.com", code: "")
    // Expected: local throw for empty code
    // Actual:   network call is made; server error returned
} catch AuthManagerError.serviceError(_) { /* server-side error */ }
```

**Impact**: AUTH-10 (empty code) is server-dependent; cannot be tested offline.

---

#### SW-BUG-04 · `Chain("unknown")` passes `assertValid()` — error deferred to wallet construction

**File**: `CrossmintCommonTypes/Blockchain/Models/Chain/Chain.swift` — `UnknownChain.isValid`

`UnknownChain.isValid` returns `true`, so `assertValid()` does not throw for arbitrary strings. The error surfaces only later, inside `buildWallet()`, as `walletInvalidType`.

**Reproduce** — Swift only (error is local, never reaches the network):
```swift
let unknownChain = Chain("bitcoin")

// assertValid() silently passes — BUG
unknownChain.assertValid()  // ← no throw; isValid == true for UnknownChain

// Error deferred to wallet construction
do {
    _ = try await wallets.createWallet(chain: unknownChain, recovery: ApiKeySigner())
} catch WalletError.walletInvalidType {
    // Error arrives here, not at assertValid()
}
```

If `buildWallet` did not catch it and the request were sent, the server would reject it:
```bash
curl -s -X POST "$BASE/2025-06-09/wallets/me" \
  -H "X-API-KEY: $SK_KEY" \
  -H "Content-Type: application/json" \
  -d '{"chainType":"bitcoin","type":"smart","config":{"adminSigner":{"type":"api-key"}}}'
# Server returns 400 Bad Request
```

**Impact**: WC-13/WC-14 error arrives later than expected; callers relying on `assertValid()` for early-exit will miss it.

---

### §B — Confirmed Local Behavior (no network required)

---

#### EVM address validation is local

`EVMWallet.sendTransaction(to:value:data:)` validates the recipient address via `EVMAddress(address:)` **before** any network call. Invalid or empty addresses throw immediately.

```swift
do {
    _ = try await evmWallet.sendTransaction(to: "0xdeadbeef", value: "0.001", data: nil)
} catch TransactionError.transactionGeneric(let msg) {
    print(msg) // "Invalid address" — thrown locally, no network call made
}
```

```bash
# This curl would only be reached if local validation passed — it doesn't:
curl -s -X POST "$BASE/2025-06-09/wallets/me:evm/tokens/base-sepolia:eth/transfers" \
  -H "X-API-KEY: $CK_KEY" \
  -H "Authorization: Bearer $JWT" \
  -H "Content-Type: application/json" \
  -d '{"recipient":"0xdeadbeef","amount":"0.001"}'
```

---

#### Production key rejects testnet chain locally

When a production API key is paired with a testnet chain, `WalletError.invalidChain` is thrown locally before any network call.

```swift
// sdk initialized with a production key
do {
    _ = try await wallets.createWallet(chain: .baseSepolia, recovery: ApiKeySigner())
} catch WalletError.invalidChain {
    // Thrown locally — no request sent
}
```

---

#### `CrossmintClient.sdk()` is a process-wide singleton

The first call to `CrossmintClient.sdk(apiKey:)` caches the instance. Subsequent calls with a different key return the same object.

```swift
let a = try CrossmintClient.sdk(apiKey: keyA)
let b = try CrossmintClient.sdk(apiKey: keyB) // returns 'a', keyB is ignored
assert(a === b) // true
```

---

### §C — Staging API Constraints

---

#### FUND: Only `usdxm` is supported for wallet funding in staging

```bash
# Fails — ETH not supported:
curl -s -X POST "$BASE/v1-alpha2/wallets/$WALLET_ADDR/balances" \
  -H "X-API-KEY: $CK_KEY" \
  -H "Authorization: Bearer $JWT" \
  -H "Content-Type: application/json" \
  -d '{"token":"eth","amount":1,"chain":"base-sepolia"}'
# Response: {"message":"token: Only USDXM is supported for funding wallets"}

# Succeeds — usdxm is the only accepted token:
curl -s -X POST "$BASE/v1-alpha2/wallets/$WALLET_ADDR/balances" \
  -H "X-API-KEY: $CK_KEY" \
  -H "Authorization: Bearer $JWT" \
  -H "Content-Type: application/json" \
  -d '{"token":"usdxm","amount":1,"chain":"base-sepolia"}'
```

---

#### HIST: Solana `listTransfers` requires a non-empty `tokens` query param

```bash
# Fails — no tokens param (SDK sends nothing when tokens array is empty):
curl -s "$BASE/unstable/wallets/me:solana/transfers?chain=solana&status=successful" \
  -H "X-API-KEY: $CK_KEY" \
  -H "Authorization: Bearer $JWT"
# Response: {"message":"tokens: tokens is required"}

# Succeeds — at least one token required:
curl -s "$BASE/unstable/wallets/me:solana/transfers?chain=solana&status=successful&tokens=usdc" \
  -H "X-API-KEY: $CK_KEY" \
  -H "Authorization: Bearer $JWT"
```

---

#### WC: Client key (`ck_`) requires a user-controlled admin signer

`ck_staging_` keys + user JWT must use `email` or `passkey` as the admin signer. `api-key` is a server-side custodial signer and is rejected when a client key is used.

```bash
# Fails — api-key signer not allowed with ck_ key:
curl -s -X POST "$BASE/2025-06-09/wallets/me" \
  -H "X-API-KEY: $CK_KEY" \
  -H "Authorization: Bearer $JWT" \
  -H "Content-Type: application/json" \
  -d '{"chainType":"evm","type":"smart","config":{"adminSigner":{"type":"api-key"}}}'
# Response: 500 Internal Server Error

# Succeeds — email signer is accepted:
curl -s -X POST "$BASE/2025-06-09/wallets/me" \
  -H "X-API-KEY: $CK_KEY" \
  -H "Authorization: Bearer $JWT" \
  -H "Content-Type: application/json" \
  -d "{\"chainType\":\"evm\",\"type\":\"smart\",\"config\":{\"adminSigner\":{\"type\":\"email\",\"email\":\"$EMAIL\"}}}"
```

---

### §D — Staging Auth Flow (reference curl sequence)

```bash
# Step 1 — send OTP email
curl -s -X POST "$BASE/2024-09-26/session/sdk/auth/otps/send" \
  -H "X-API-KEY: $CK_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\"}"
# Response: {"emailId":"<state>"}  — save the emailId as EMAIL_ID

# Step 2 — submit OTP code (replace 123456 with the code from the inbox)
curl -s -X POST \
  "$BASE/2024-09-26/session/sdk/auth/authenticate\
?signinAuthenticationMethod=email\
&email=$EMAIL\
&token=123456\
&state=$EMAIL_ID\
&callbackUrl=$BASE/2024-09-26/session/sdk/auth/authenticate/callback" \
  -H "X-API-KEY: $CK_KEY"
# Response: {"jwt":"<bearer-token>","refreshToken":"...","expiresAt":...}
# Save jwt as JWT

# Step 3 — use the JWT for wallet operations
curl -s "$BASE/2025-06-09/wallets/me:evm" \
  -H "X-API-KEY: $CK_KEY" \
  -H "Authorization: Bearer $JWT"
```

---

### §E — Test Infrastructure Notes

| Topic | Detail |
|-------|--------|
| Mailnesia RSS URL | `https://mailnesia.com/rss/<name>` — NOT `mailbox/<name>?rss=1` (that URL returns HTML) |
| Mailnesia item ordering | Items are **not** sorted chronologically or by ID. Use GUID-based detection: snapshot `<guid>` set before OTP send; poll until a new GUID appears |
| OTP email pairs | Crossmint staging sends two emails per OTP request (HTML + plain text). The GUID approach checks all new GUIDs for a 6-digit code |
| Actor concurrency | Swift actors release during `await`; multiple concurrent test callers can each see `_wallets == nil`. Fixed with a Task-based pattern so only one auth flow runs |
| `TestEmailSigner` | Headless email signer for tests — provides `EmailSignerData(email:)` without WKWebView. `sign(message:)` always throws; suitable for read-only wallet operations only |

---

## 24. Known Gaps (per Flutter Gist — April 2026)


| Gap | Affected SDK | Action |
|-----|-------------|--------|
| Phone auth login | Flutter | Mark test FL-PHONE as expected FAIL |
| Passkey signer (experimental) | Flutter | Test FL-14 expected to require workaround |
| External wallet as active signer | Flutter | Requires host app callbacks — document |
| Solana device signer | Flutter | Test FL-13 should return clear error |
| `signMessage` / `signTypedData` | Kotlin, Flutter | Not exposed directly — via TEE only |
| NFTs | Kotlin | Not in public API |
| Transfer history | Kotlin | Not in public API |
| OAuth (Google/Twitter/Apple) | Kotlin, Swift | Swift/Kotlin: N/A |
