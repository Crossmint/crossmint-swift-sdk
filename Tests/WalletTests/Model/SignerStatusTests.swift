import Foundation
import Testing
@testable import Wallet

@Suite("Signer Status", .tags(.unit))
struct SignerStatusTests {
    @Test
    func fromParsesEachKnownRawValue() {
        #expect(SignerStatus.from("pending") == .pending)
        #expect(SignerStatus.from("awaiting-approval") == .awaitingApproval)
        #expect(SignerStatus.from("active") == .active)
        #expect(SignerStatus.from("failed") == .failed)
    }

    @Test
    func fromTreatsSuccessAsActive() {
        #expect(SignerStatus.from("success") == .active)
    }

    @Test
    func fromFallsBackToUnknownForUnrecognizedValue() {
        #expect(SignerStatus.from("some-new-status") == .unknown)
    }

    @Test
    func fromFallsBackToUnknownForNil() {
        #expect(SignerStatus.from(nil) == .unknown)
    }

    @Test
    func decodesSuccessRawStringAsActive() throws {
        let status = try JSONDecoder().decode(SignerStatus.self, from: Data(#""success""#.utf8))
        #expect(status == .active)
    }

    @Test
    func decodesUnrecognizedRawStringAsUnknownInsteadOfThrowing() throws {
        let status = try JSONDecoder().decode(SignerStatus.self, from: Data(#""something-new""#.utf8))
        #expect(status == .unknown)
    }
}
