@AGENTS.md

## Running tests

- `make test` — unit suite on the iOS simulator (what CI runs). `swift test` does not work on a Mac host: the package is iOS-only, the SwiftLint plugin needs macOS 12, and `PasskeyDelegate` uses `UIApplication` unguarded.
- `make integration-test` — real-API flows; needs `TEST_RUNNER_PREVIEW_CK_KEY`.
- A single suite: `xcodebuild -scheme CrossmintClientSDK -testPlan CrossmintSDK -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' test -skipPackagePluginValidation -only-testing:<Target>/<Suite>`.
