import Testing
import WebKit
@testable import Web

@Suite("SignerWebStorage", .tags(.unit))
@MainActor
struct SignerWebStorageTests {
    @Test("uses a non-persistent store so no signer state is written to disk")
    func usesNonPersistentStore() {
        #expect(SignerWebStorage().dataStore.isPersistent == false)
    }
}
