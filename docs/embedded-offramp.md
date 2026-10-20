# Embedded offramp

The offramp page requires the backend rollout tracked in OFFRAMP-667. Keep integrations on staging until that rollout and device KYC checks are complete.

Your backend mints the session. The iOS app receives only its session ID, client secret, and a public client API key. V1 sends those session credentials in the page URL; avoid recording WebView URLs or placing them in analytics.

```swift
import CrossmintClient

let configuration = try EmbeddedOfframpConfiguration(
    apiKey: "ck_staging_...",
    credentials: .init(sessionId: sessionId, clientSecret: clientSecret),
    locale: "en",
    appearance: ["variables": ["colors": ["backgroundPrimary": "#ffffff"]]]
)

CrossmintEmbeddedOfframp(
    configuration: configuration,
    payer: { transaction in
        // Validate payerAddress and chain against the connected wallet before submitting.
        try await yourWallet.signAndSend(transaction)
    },
    callbacks: .init(
        onStatusChange: { status in /* update your app */ },
        onComplete: { result in /* deposit matched; bank delivery can still be pending */ },
        onError: { error in /* use reason and retriable */ }
    )
)
.frame(minHeight: 600)
```

The payer callback receives the serialized transaction unchanged and returns the on-chain transaction hash/signature. Throw `OfframpSignatureRejected` only when you know the wallet declined before any broadcast. A timeout or generic error might follow a successful broadcast and must remain an ordinary error. Do not dismiss or replace the component while the wallet is signing: late success is delivered while the same page remains mounted.

The Swift wallet SDK accepts serialized Solana transactions through `SolanaWallet.sendTransaction(transaction:)` returning `TransactionSummary.hash`. Its EVM wallet API currently takes separate recipient, value, and calldata fields; it does not provide a serialized EVM transaction parser. This component therefore exposes a payer callback rather than an automatic Crossmint-wallet adapter. An EVM integration needs a wallet library that understands the supplied serialized transaction; do not treat the whole serialized transaction as calldata. Preserve chain, payer, transfer data, and Solana memo when using a wallet adapter.

Add `NSCameraUsageDescription` and `NSMicrophoneUsageDescription` to the host app's Info.plist for KYC. WebKit retains its media permission prompt. Inline media is enabled; actual provider camera permission and capture still require testing on a device. The component uses an ephemeral website data store, so dismissing it does not persist KYC browser state on disk.

Use `onHeightChange` if your layout follows the page's reported height, or give the component an explicit frame. Appearance accepts an Encodable value with the embedded checkout `fonts`, `variables`, and `rules` shape.
