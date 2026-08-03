import Foundation
import Testing
@testable import Wallet

@Suite("Chain Registration Entry Decoding", .tags(.unit))
struct ChainRegistrationEntryTests {
    @Test
    func decodesSuccessStatusAsActive() throws {
        let json = """
        {"id": "sig1", "status": "success"}
        """
        let entry = try JSONDecoder().decode(ChainRegistrationEntry.self, from: Data(json.utf8))

        #expect(entry.status == .active)
        #expect(entry.awaitsApproval == false)
    }

    @Test
    func decodesUnrecognizedStatusAsUnknownInsteadOfThrowing() throws {
        let json = """
        {"id": "sig1", "status": "some-new-status"}
        """
        let entry = try JSONDecoder().decode(ChainRegistrationEntry.self, from: Data(json.utf8))

        #expect(entry.status == .unknown)
        #expect(entry.awaitsApproval == false)
    }

    @Test
    func decodesMissingStatusAsUnknownInsteadOfThrowing() throws {
        let json = """
        {"id": "sig1"}
        """
        let entry = try JSONDecoder().decode(ChainRegistrationEntry.self, from: Data(json.utf8))

        #expect(entry.status == .unknown)
    }

    @Test
    func decodesAwaitingApprovalAsAwaitingApproval() throws {
        let json = """
        {"id": "sig1", "status": "awaiting-approval"}
        """
        let entry = try JSONDecoder().decode(ChainRegistrationEntry.self, from: Data(json.utf8))

        #expect(entry.status == .awaitingApproval)
        #expect(entry.awaitsApproval == true)
    }
}
