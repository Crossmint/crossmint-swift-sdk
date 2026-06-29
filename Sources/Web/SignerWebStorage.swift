import WebKit

@MainActor
protocol SignerStorage {
    var dataStore: WKWebsiteDataStore { get }
    func clear() async
}

@MainActor
struct SignerWebStorage: SignerStorage {
    let dataStore: WKWebsiteDataStore = .nonPersistent()

    func clear() async {
        await dataStore.removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            modifiedSince: .distantPast
        )
    }
}
