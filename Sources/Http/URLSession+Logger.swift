import Foundation
import Logger
import Utils

extension URLSession {
    static func log(data: Data, response: URLResponse) {
#if DEBUG
        guard getBoolEnvironment("CROSSMINT_SDK_HTTP_LOGS") || isRunningInPlayground() else {
            return
        }
        var message: String = ""
        message.append("\n=== 🌐 Network Response ===\n")

        if let httpResponse = response as? HTTPURLResponse {
            message.append("📍 URL: \(httpResponse.url?.absoluteString ?? "nil")\n")
            // swiftlint:disable:next line_length
            message.append("📊 Status: \(httpResponse.statusCode) \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))\n")

            message.append("📋 Headers:\n")
            httpResponse.allHeaderFields.forEach { key, value in
                message.append("   \(key): \(value)\n")
            }
        }

        message.append("\n📦 Body:\n")
        if let json = try? JSONSerialization.jsonObject(with: data),
           let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            message.append(prettyString + "\n")
        } else if let string = String(data: data, encoding: .utf8) {
            message.append(string + "\n")
        } else {
            message.append("   <binary data of \(data.count) bytes>\n")
        }

        message.append("\n=== End Response ===\n")

        Logger.http.info(message)
#endif
    }
}
