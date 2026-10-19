import Foundation
import Testing
import TestsUtils
@testable import Http

@Suite("Network kill-switch", .tags(.unit))
struct NetworkKillSwitchTests {
    @Test func failsALiveRequestAndNamesIt() async throws {
        NetworkKillSwitch.install()
        let request = URLRequest(url: try #require(URL(string: "https://staging.crossmint.com/api/ping")))

        await #expect {
            try await HTTPClient.live.fetch(request)
        } throws: { error in
            guard case .unknown(let cause) = error as? NetworkError else { return false }
            return cause.localizedDescription.contains("GET https://staging.crossmint.com/api/ping")
        }
    }
}
