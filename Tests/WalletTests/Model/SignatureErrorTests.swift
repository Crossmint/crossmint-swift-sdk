import Foundation
import Testing
@testable import Wallet

private struct StubUnderlyingError: Error, CustomStringConvertible {
    var description: String { "underlyingCoreCryptoError(error: -25293)" }
}

@Suite("SignatureError")
struct SignatureErrorTests {

    @Test("signingFailed exposes the code and forwards the underlying error")
    func signingFailedForwardsUnderlying() {
        let error = SignatureError.signingFailed(underlyingError: StubUnderlyingError())
        #expect(error.code == "SIGNATURE_SIGNING_FAILED")
        #expect((error.underlyingError as? StubUnderlyingError) != nil)
    }

    @Test("description carries the underlying code once and message stays clean")
    func descriptionCarriesCodeOnce() {
        let error = SignatureError.signingFailed(underlyingError: StubUnderlyingError())
        #expect(occurrences(of: "-25293", in: error.description) == 1)
        #expect(!error.message.contains("-25293"))
    }
}

private func occurrences(of needle: String, in haystack: String) -> Int {
    haystack.components(separatedBy: needle).count - 1
}
