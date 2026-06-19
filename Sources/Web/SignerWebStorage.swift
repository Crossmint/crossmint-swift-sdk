import WebKit

/// Non-persistent storage for the signer web view.
@MainActor
struct SignerWebStorage {
    let dataStore: WKWebsiteDataStore = .nonPersistent()

    func clear() async {
        await dataStore.removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            modifiedSince: .distantPast
        )
    }
}
