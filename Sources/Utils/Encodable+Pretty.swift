import Foundation

extension Encodable {
    public func json(prettyPrinted: Bool = false) -> String {
        let encoder = JSONEncoder()
        if prettyPrinted {
            encoder.outputFormatting = .prettyPrinted
        }
        if let jsonData = try? encoder.encode(self.self),
            let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }

        return ""
    }
}
