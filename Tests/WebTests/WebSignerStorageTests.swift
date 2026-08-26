import Testing
import WebKit
@testable import Web

@Suite("WebSignerStorage", .tags(.unit))
@MainActor
struct WebSignerStorageTests {
    @Test("uses a non-persistent store so no signer state is written to disk")
    func usesNonPersistentStore() {
        #expect(WebSignerStorage().dataStore.isPersistent == false)
    }
}
