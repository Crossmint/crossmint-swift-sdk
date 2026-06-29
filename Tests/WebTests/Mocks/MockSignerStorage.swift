import WebKit
@testable import Web

@MainActor
final class MockSignerStorage: SignerStorage {
    let dataStore: WKWebsiteDataStore = .nonPersistent()
    func clear() async {}
}
