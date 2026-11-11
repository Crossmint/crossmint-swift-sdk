//
//  LogMask.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 11/11/26.
//

package enum LogMask {
    package static func locator(_ locator: String) -> String {
        let parts = locator.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return locator }
        let (type, identifier) = (parts[0], parts[1])

        switch type {
        case "email":
            return "\(type):\(email(identifier))"
        case "phone", "phoneNumber":
            return "\(type):\(phone(identifier))"
        default:
            return locator
        }
    }

    private static func email(_ identifier: Substring) -> String {
        guard let first = identifier.first,
              let domainStart = identifier.lastIndex(of: "@"),
              domainStart != identifier.startIndex else {
            return "***"
        }
        return "\(first)***\(identifier[domainStart...])"
    }

    private static func phone(_ identifier: Substring) -> String {
        let number = identifier.prefix { $0 != ":" }
        let chainSuffix = identifier[number.endIndex...]
        let digits = number.filter(\.isNumber)
        guard digits.count > 4 else { return "***\(chainSuffix)" }

        let plus = number.hasPrefix("+") ? "+" : ""
        return "\(plus)\(digits.prefix(1))***\(digits.suffix(4))\(chainSuffix)"
    }
}
