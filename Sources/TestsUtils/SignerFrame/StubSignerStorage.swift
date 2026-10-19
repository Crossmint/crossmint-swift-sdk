import Web
import WebKit

@MainActor
package final class StubSignerStorage: SignerStorage {
    package let dataStore: WKWebsiteDataStore = .nonPersistent()

    package init() {}

    package func clear() async {}
}
