import Foundation
import CrossmintService

public class GetFromFile {
    struct Error: Swift.Error {
        let message: String
    }

    public static func getModelFrom<T>(fileName: String, bundle: Bundle) throws -> T where T: Decodable {
        guard let url = bundle.url(forResource: fileName, withExtension: "json") else {
            throw Error(message: "Error: File (\(fileName).json not found.")
        }

        do {
            return try DefaultJSONCoder().decode(T.self, from: try Data(contentsOf: url))
        } catch {
            throw Error(message: "Error: Decoding error \(error)")
        }
    }
}
