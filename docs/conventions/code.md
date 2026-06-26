# Code Conventions

## Protocol-First Design

Expose behavior through protocols, keep concrete types internal. Protocols live in the same module as their primary consumer; implementations are `internal` or `package` unless they need to be subclassed. External consumers only import protocols and public value types.

## Naming

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

## Abstraction Discipline

Inline code unless the abstraction meets one of these criteria:
- It self-documents a non-obvious relationship or hides significant complexity
- It maintains state the algorithm requires across iterations
- It has multiple, current implementations (e.g. a protocol with two concrete types in active use)

A helper function that just renames a call, or a type that wraps only one thing, adds indirection without value. Remove it.

## Business Logic Placement

Coordination, polling, and retry belong in `DefaultCrossmintWallets` or wallet extensions. Services are single-call — they don't know or care about the flow around them.

## Actors for Mutable Async State

Use `actor` for types with mutable state accessed from multiple async contexts. `@unchecked Sendable` hides real data races — fix the isolation instead. The one exception is test mocks where mutations are test-isolated; see `docs/conventions/tests.md`.

## Optional JSON Body Fields

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

## Simple Expressions Over Chains

Split complex one-liners into named intermediate steps. Clarity beats brevity:

```swift
// Avoid — what does this do?
let result = try await service.fetch(id: pending.pendingApproval?.id ?? "").flatMap { ... }

// Prefer — each step is obvious
guard let approvalId = pending.pendingApproval?.id else { return }
let approval = try await service.fetch(id: approvalId)
```

## Public API Surface Discipline

Before making anything `public`, ask: who outside this module calls this? If the answer is "only sibling modules," use `package` access. If the answer is "nobody yet," keep it `internal`. Exposing unnecessary public surface makes future refactors painful and forces semver consideration.

The same applies to stored properties: if a property is only read during `init`, use a local variable instead.

## Error Type Requirements

All new error types must conform to `CrossmintError`. Error codes use `SCREAMING_SNAKE_CASE` (e.g., `WALLET_NOT_FOUND`). Provide a `recoverySuggestion` whenever the developer can take a specific action to fix the problem. Errors communicate exactly two things: whether the caller should retry, and whether the fault is theirs or the system's. Don't create subclasses or cases beyond what's needed to express those two distinctions.

## Function Inputs

Functions should depend only on what they use. Prefer passing specific values over large objects when only a subset of fields is needed — this keeps the function usable in a wider range of contexts and makes its dependencies explicit.

## Complexity Threshold

Before adding background tasks, timers, or retry loops, check whether a simpler pre-call check would suffice, and whether the other SDKs (React Native, Kotlin) do the same thing. Complexity that isn't warranted by the feature and not matched cross-platform creates drift.

## Swift Concurrency Patterns

**Typed throws.** Use domain-typed errors where the failure set is known at the call site. The codebase uses `throws(WalletError)`, `throws(TransactionError)`, etc. Don't use untyped `throws` for internal methods whose errors are knowable — the compiler enforces exhaustiveness and eliminates the need for casts.

**`@MainActor` propagation.** `CrossmintSDK` is `@MainActor`. Code that updates UI or calls into the singleton must run on the main actor. Use `await MainActor.run { }` to hop explicitly rather than `DispatchQueue.main.async` — that is UIKit-era code that breaks structured concurrency.

**Structured concurrency.** Use `async let` for parallel independent calls. Use `TaskGroup` when the fan-out count is dynamic. Avoid `Task.detached` unless you explicitly need to break task inheritance (priority, cancellation, actor context) — detached tasks orphan work and make testing harder.

## Common Mistakes to Avoid

- **Storing init-only values as properties.** If a value is used during `init` and never again, assign it to a local, not `self.property`. Stored properties signal that the value is needed beyond init.

- **Leaking internal types into the public API.** The HTTP client (`crossmintService`), internal service types, and factory classes must not appear in any public protocol or `public` property. Before adding a `public` property, ask whether external developers actually need it.

- **Synthesized `Encodable` with optional fields.** Synthesized conformance encodes `nil` as `null`. For any request body with optional fields, use `CodingKeys` + `encodeIfPresent`. See above.

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
