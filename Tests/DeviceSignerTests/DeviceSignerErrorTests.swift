import Foundation
import Testing
@testable import DeviceSigner

private struct StubUnderlyingError: Error, CustomStringConvertible {
    var description: String { "underlyingCoreCryptoError(error: -25293)" }
}

@Suite("DeviceSignerError")
struct DeviceSignerErrorTests {

    @Test("signingFailed exposes the code and the underlying error")
    func signingFailedExposesUnderlying() {
        let error = DeviceSignerError.signingFailed(
            operation: "Secure Enclave signature",
            underlyingError: StubUnderlyingError()
        )
        #expect(error.code == "DEVICE_SIGNER_SIGNING_FAILED")
        #expect((error.underlyingError as? StubUnderlyingError) != nil)
    }

    @Test("signingFailed message keeps the operation and the underlying code once")
    func signingFailedMessageKeepsUnderlyingCode() {
        let error = DeviceSignerError.signingFailed(
            operation: "Secure Enclave signature",
            underlyingError: StubUnderlyingError()
        )
        #expect(error.message.contains("Secure Enclave signature"))
        #expect(occurrences(of: "-25293", in: error.message) == 1)
    }

    @Test("localizedDescription does not surface the underlying code")
    func localizedDescriptionStaysClean() {
        let error = DeviceSignerError.signingFailed(
            operation: "Secure Enclave signature",
            underlyingError: StubUnderlyingError()
        )
        #expect(!error.localizedDescription.contains("-25293"))
    }

    @Test("cases without a signing failure have no underlying error")
    func noUnderlyingForOtherCases() {
        #expect(DeviceSignerError.keyNotFound.underlyingError == nil)
    }
}

private func occurrences(of needle: String, in haystack: String) -> Int {
    haystack.components(separatedBy: needle).count - 1
}
