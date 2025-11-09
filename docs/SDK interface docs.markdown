# Crossmint Swift SDK Interface Overview

This document outlines the primary interface of the Crossmint Swift SDK. The SDK is designed to be accessed starting from an instance of `ClientSDK`, which then provides access to various managers and services for interacting with the Crossmint platform.

## Core Components

The SDK is composed of several key protocols that define its capabilities:

1.  **`ClientSDK`**: The main entry point to the SDK.
2.  **`AuthManager`**: Handles user authentication and session management.
3.  **`CrossmintWallets`**: Manages user wallets, including creation and retrieval.
4.  **`Wallet`**: Represents a generic user wallet and its associated operations.
5.  **`EVMWallet`**: A specialized version of `Wallet` for EVM-compatible chains, adding EVM-specific transaction capabilities.

## Component Details

### 1. `ClientSDK`

The `ClientSDK` protocol is the root object for interacting with the SDK.

```swift
public protocol ClientSDK {
    func crossmintWallets() -> CrossmintWallets
    var authManager: AuthManager { get }
    var crossmintService: CrossmintService { get }
}
```

*   **`crossmintWallets() -> CrossmintWallets`**: Returns an instance of `CrossmintWallets` for wallet management.
*   **`authManager: AuthManager`**: Provides access to the `AuthManager` for authentication tasks.
*   **`crossmintService: CrossmintService`**: Provides access to the underlying `CrossmintService`. **Note:** This is currently utilized for Payments-related work, but the SDK design intends for this to be refactored or encapsulated differently in the future. Direct usage might change.

### 2. `AuthManager`

The `AuthManager` protocol is responsible for handling all aspects of user authentication.

```swift
public protocol AuthManager: Sendable {
    var jwt: String? { get async }
    var email: String? { get async }
    var authenticationStatus: AuthenticationStatus { get async throws(AuthError) }

    func otpAuthentication(
        email: String,
        code: String?,
        forceRefresh: Bool
    ) async throws(AuthManagerError) -> OTPAuthenticationStatus

    #if DEBUG
    func oneTimeSecretAuthentication(
        oneTimeSecret: String
    ) async throws(AuthManagerError) -> OTPAuthenticationStatus
    #endif

    func logout() async throws(AuthManagerError) -> OTPAuthenticationStatus
    func reset() async -> OTPAuthenticationStatus
}
```

*   **Properties**:
    *   `jwt: String?`: Asynchronously retrieves the current JSON Web Token if the user is authenticated.
    *   `email: String?`: Asynchronously retrieves the authenticated user's email.
    *   `authenticationStatus: AuthenticationStatus`: Asynchronously retrieves the current authentication state of the user.
*   **Methods**:
    *   `otpAuthentication(...)`: Initiates or completes OTP (One-Time Password) authentication.
    *   `oneTimeSecretAuthentication(...)` (DEBUG only): Authenticates using a one-time secret.
    *   `logout()`: Logs out the current user.
    *   `reset()`: Resets the authentication state.
*   **Associated Enums**:
    *   `AuthManagerError`: Defines errors that can occur during authentication.
    *   `AuthenticationStatus`: Represents the different states of authentication (e.g., `nonAuthenticated`, `authenticating`, `authenticated`).
    *   `OTPAuthenticationStatus`: Represents the states specific to OTP authentication flow (e.g., `emailSent`, or wrapping `AuthenticationStatus`).

### 3. `CrossmintWallets`

The `CrossmintWallets` protocol provides an interface for managing wallets. When a wallet is retrieved or created, it could be a generic `Wallet` or a more specific type like `EVMWallet`, depending on the chain and type requested.

```swift
public protocol CrossmintWallets: Sendable {
    func hasWallet(
        type: WalletType // Defaults to .evmSmartWallet
    ) async throws(WalletError) -> Bool

    func getOrCreateWallet(
        _ chain: Chain,
        type: WalletType, // Defaults to .evmSmartWallet
        signer: any Signer
    ) async throws(WalletError) -> Wallet // Returns a Wallet, which could be an EVMWallet
}
```

*   **Methods**:
    *   `hasWallet(type: WalletType)`: Checks if a wallet of a specific type exists for the user.
    *   `getOrCreateWallet(_ chain: Chain, type: WalletType, signer: any Signer)`: Retrieves an existing wallet or creates a new one for the specified blockchain, wallet type, and signer. The returned `Wallet` instance might conform to more specific protocols like `EVMWallet`.

### 4. `Wallet`

The `Wallet` protocol represents a user's wallet and allows performing various operations on it.

```swift
public protocol Wallet: Sendable {
    var linkedUser: LinkedUser? { get }
    var address: String { get }
    var createdAt: Date { get }
    var type: WalletType { get }
    var config: WalletConfig { get }

    func getNFT(
        chain: Chain,
        page: Int, // Defaults to 1
        nftsPerPage: Int // Defaults to 10
    ) async throws(WalletError) -> [NFT]

    func getBalance(
        of currencies: [CryptoCurrency], // Can be single currency
        on chains: [Chain]           // Can be single chain or all if currencies is empty
    ) async throws(WalletError) -> Balances

    func getTransaction(
        id: String
    ) async throws(WalletError) -> Transaction

    func fund(
        token: CryptoCurrency,
        amount: Int,
        chain: Chain
    ) async throws(WalletError)
}
```

*   **Properties**:
    *   `linkedUser: LinkedUser?`: Information about the user linked to this wallet.
    *   `address: String`: The public address of the wallet.
    *   `createdAt: Date`: The creation date of the wallet.
    *   `type: WalletType`: The type of the wallet (e.g., EVM, Solana).
    *   `config: WalletConfig`: Configuration details specific to this wallet.
*   **Methods**:
    *   `getNFT(...)`: Retrieves a list of NFTs owned by the wallet on a specific chain.
    *   `getBalance(...)`: Retrieves the balance of specified crypto currencies on specified chains.
    *   `getTransaction(id: String)`: Retrieves details of a specific transaction.
    *   `fund(...)`: Funds the wallet with a specified amount of a token on a chain (Note: This is typically a testnet/devnet utility).

### 5. `EVMWallet`

The `EVMWallet` protocol extends the `Wallet` protocol with functionality specific to EVM-compatible blockchains.

```swift
public protocol EVMWallet: Wallet {
    func send(
        to address: EVMPublicKeyAddress,
        data: String?,
        value: BigInt?,
        chain: EVMBlockchain
    ) async throws(TransactionError) -> Transaction
}
```

*   **Inherits from**: `Wallet`.
*   **Methods**:
    *   `send(...)`: Sends a transaction on an EVM-compatible chain. This allows for sending native currency (e.g., ETH) by specifying `value`, interacting with smart contracts by providing `data`, or both.


## SDK Structure Diagram (Mermaid)

![mermaid diagram](./images/mermaid-diagram.png)

```mermaid
classDiagram
  ClientSDK ..> AuthManager : uses
  ClientSDK ..> CrossmintWallets : uses
  ClientSDK ..> CrossmintService : uses
  CrossmintWallets ..> Wallet : creates/retrieves
  Wallet <|-- EVMWallet : inherits
  CrossmintService o-- ServiceError
  CrossmintService o-- CrossmintServiceError

  class ClientSDK {
    +crossmintWallets(): CrossmintWallets
    +authManager: AuthManager
    +crossmintService: CrossmintService
    <<Note>> crossmintService usage for Payments is temporary
  }

  class AuthManager {
    +jwt: String?
    +email: String?
    +authenticationStatus: AuthenticationStatus
    +otpAuthentication(email, code, forceRefresh): OTPAuthenticationStatus
    +oneTimeSecretAuthentication(oneTimeSecret): OTPAuthenticationStatus
    +logout(): OTPAuthenticationStatus
    +reset(): OTPAuthenticationStatus
  }
  AuthManager o-- AuthenticationStatus
  AuthManager o-- OTPAuthenticationStatus

  class AuthenticationStatus {
    <<enumeration>>
    nonAuthenticated
    authenticating
    authenticated(email, jwt, secret)
    +isAuthenticated: Bool
  }

  class OTPAuthenticationStatus {
    <<enumeration>>
    authenticationStatus(AuthenticationStatus)
    emailSent(email, emailId)
    +isAuthenticated: Bool
    +email: String?
    +jwt: String?
  }

  class CrossmintWallets {
    +hasWallet(type: WalletType): Bool
    +getOrCreateWallet(chain: Chain, type: WalletType, signer: Signer): Wallet
  }

  class Wallet {
    +linkedUser: LinkedUser?
    +address: String
    +createdAt: Date
    +type: WalletType
    +config: WalletConfig
    +getNFT(chain, page, nftsPerPage): [NFT]
    +getBalance(currencies, chains): Balances
    +getTransaction(id): Transaction
    +fund(token, amount, chain): void
  }

  class EVMWallet {
    +send(to, data, value, chain): Transaction
  }

  class CrossmintService {
    +executeRequest(endpoint, errorType, transform): T
    +executeRequest(endpoint, errorType, transform): void
    +getApiBaseURL(): URL
    +isProductionEnvironment: Bool
  }

  class ServiceError {
    <<protocol>>
    +fromServiceError(error): Self
    +fromNetworkError(error): Self
    +errorMessage: String
  }

  class CrossmintServiceError {
    <<enumeration>>
    unknown
    invalidData(String)
    invalidApiKey(String)
    timeout
    invalidURL
    +errorMessage: String
  }

  class AuthenticatedService {
    <<protocol>>
    +authHeaders: [String: String]
  }
  AuthManager ..> AuthenticatedService : (potentially provides auth for)
  CrossmintService ..> AuthenticatedService : (may require)

```

This diagram illustrates the main relationships:
*   `ClientSDK` is the entry point. The note about `crossmintService` is included.
*   `AuthManager` manages `AuthenticationStatus` and `OTPAuthenticationStatus`. It may also be a source for `authHeaders` used by an `AuthenticatedService`.
*   `CrossmintWallets` is responsible for providing `Wallet` instances.
*   `EVMWallet` inherits from `Wallet`.