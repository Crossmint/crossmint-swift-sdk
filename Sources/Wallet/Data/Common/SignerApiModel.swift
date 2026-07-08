import Foundation

public struct SignerApiModel: Decodable, Sendable {
    public let locator: String

    init(locator: String) {
        self.locator = locator
    }

    public init(from decoder: Decoder) throws {
        // Some endpoints return the signer as a plain locator string instead of
        // an object — e.g. the stellar transfer-create response echoes
        // `params.signer` as "email:<user>" verbatim from the request.
        if let container = try? decoder.singleValueContainer(),
           let locator = try? container.decode(String.self) {
            self.locator = locator
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.locator = try container.decode(String.self, forKey: .locator)
    }

    private enum CodingKeys: CodingKey {
        case locator
    }
}
