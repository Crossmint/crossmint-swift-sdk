# App Transport Security (ATS) Configuration for TEE Attestation

## Overview

The Crossmint Swift SDK requires network access to specific endpoints for TEE (Trusted Execution Environment) attestation verification. These endpoints must be configured in your app's `Info.plist` to allow network communication.

## Required Configuration

Add the following configuration to your app's `Info.plist` file to enable TEE attestation:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
    <key>NSExceptionDomains</key>
    <dict>
        <!-- PCCS endpoint for DCAP collateral verification -->
        <key>pccs.phala.network</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <false/>
            <key>NSIncludesSubdomains</key>
            <true/>
            <key>NSExceptionRequiresForwardSecrecy</key>
            <false/>
        </dict>
        
        <!-- Phala API endpoint for attestation verification -->
        <key>cloud-api.phala.com</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <false/>
            <key>NSIncludesSubdomains</key>
            <true/>
            <key>NSExceptionRequiresForwardSecrecy</key>
            <false/>
        </dict>
        
        <!-- Crossmint signers frame (production) -->
        <key>signers.crossmint.com</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <false/>
            <key>NSIncludesSubdomains</key>
            <true/>
        </dict>
        
        <!-- Crossmint signers frame (staging) -->
        <key>staging.signers.crossmint.com</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <false/>
            <key>NSIncludesSubdomains</key>
            <true/>
        </dict>
    </dict>
</dict>
```

## Endpoint Descriptions

### pccs.phala.network
Used for retrieving DCAP (Data Center Attestation Primitives) collateral during Intel TDX quote verification. This endpoint provides cryptographic certificates and revocation information needed to verify the TEE hardware attestation.

### cloud-api.phala.com
Phala's cloud API service for TEE attestation verification. Provides an alternative verification method when local WASM-based verification is not available or fails.

### signers.crossmint.com
Production endpoint for the Crossmint non-custodial signer frame. This is where the TEE attestation documents are fetched from.

### staging.signers.crossmint.com
Staging endpoint for the Crossmint non-custodial signer frame. Used during development and testing.

## Troubleshooting

### "Load failed" errors during attestation
If you see "Load failed" errors in the logs during TEE attestation, verify that:
1. The ATS configuration is present in your `Info.plist`
2. All required domains are listed in `NSExceptionDomains`
3. Your app has network permissions

### Network debugging
To debug network issues:
1. Enable WKWebView inspection in debug builds (already enabled in SDK)
2. Use Safari Web Inspector to view network requests
3. Use Charles Proxy or Proxyman to intercept and inspect network traffic

## Security Considerations

All endpoints use HTTPS and maintain secure connections. The `NSExceptionRequiresForwardSecrecy` setting is disabled for PCCS and Phala API endpoints to ensure compatibility with their TLS configurations, but all traffic remains encrypted.

## Additional Resources

- [Apple ATS Documentation](https://developer.apple.com/documentation/bundleresources/information_property_list/nsapptransportsecurity)
- [WKWebView Documentation](https://developer.apple.com/documentation/webkit/wkwebview)
- [Phala Network Documentation](https://docs.phala.network/)
