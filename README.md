## Crossmint Swift SDK

### First Steps
Once the project is cloned, it's ready to be opened with Xcode. To do this, simply double-click the `Crossmint SDK.xcworkspace` file. This will open the SDK along with a small companion demo app that can be used as a test bed.
The app will start out of the box, but it will start showing error dialogs as soon as the API is used. To fix that, we need to add a couple of environment variables: `CROSSMINT_API_KEY` and `CROSSMINT_WHITELISTED_DOMAIN`. 

Take a look at the following screenshot to see a valid configuration. (As you can see, there is another environment variable that it's used to show all the network logs in Xcode)

[![Xcode screenshot showing the scheme configuration](/images/crossmint-demo-environment-setup.png)

### How to Run Tests
Run the unit suite with `make test`. It builds for the iOS simulator through `xcodebuild`, which is what CI runs.

`swift test` does not work on a Mac host: the package declares only iOS, so a host build takes SwiftPM's default macOS 10.13 minimum, below the macOS 12 that `SwiftLintBuildToolPlugin` requires, and four sources import UIKit. Both would need changes to the package before `swift test` could run (tracked as QA-112).

Other targets: `make integration-test` runs the real-API flows (needs `TEST_RUNNER_PREVIEW_CK_KEY`), `make lint` runs SwiftLint.
