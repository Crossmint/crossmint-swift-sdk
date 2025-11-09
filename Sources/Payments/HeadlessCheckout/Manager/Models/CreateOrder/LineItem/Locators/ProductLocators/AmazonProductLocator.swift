import Foundation
import Utils

public struct AmazonProductLocator: Codable, Sendable, CustomStringConvertible {
    public static let amazonPrefix = "amazon"

    public let platform: String
    public let asin: String

    public init(platform: String, asin: String) throws(AmazonProductLocatorError) {
        guard platform == Self.amazonPrefix else {
            throw AmazonProductLocatorError.invalidPrefix(
                expected: Self.amazonPrefix, got: platform)
        }

        guard Self.isValidAsin(asin) else {
            throw AmazonProductLocatorError.invalidAmazonUrlOrAsin(asin)
        }

        self.platform = platform
        self.asin = asin
    }

    /// Throws initializer that parses a string in the format "amazon:ASIN" or "amazon:URL"
    /// - Parameter stringValue: The string to parse
    /// - Throws: AmazonProductLocatorError if the string is invalid
    public init(from stringValue: String) throws {
        if isEmpty(stringValue) {
            throw AmazonProductLocatorError.emptyLocator
        }

        let components = stringValue.split(separator: ":", maxSplits: 1).map(String.init)
        guard components.count > 0 else {
            throw AmazonProductLocatorError.emptyLocator
        }

        let prefix = components[0]
        if prefix != Self.amazonPrefix {
            throw AmazonProductLocatorError.invalidPrefix(expected: Self.amazonPrefix, got: prefix)
        }

        guard components.count > 1 else {
            throw AmazonProductLocatorError.missingAsinOrUrl
        }

        let restJoined = components[1]

        var asin: String? = Self.asinFromUrl(restJoined)

        // If not a valid URL or couldn't extract ASIN from URL, check if the value itself is a valid ASIN
        if isEmpty(asin) && Self.isValidAsin(restJoined) {
            asin = restJoined
        }

        guard let validAsin = asin, !isEmpty(validAsin) else {
            throw AmazonProductLocatorError.invalidAmazonUrlOrAsin(restJoined)
        }

        self.platform = prefix
        self.asin = validAsin
    }

    /// Converts the AmazonProductLocator to its string representation
    /// - Returns: A string in the format "amazon:ASIN"
    public var description: String {
        return "\(platform):\(asin)"
    }

    /// Extracts ASIN from an Amazon URL
    /// - Parameter url: The Amazon URL
    /// - Returns: The ASIN if found, nil otherwise
    private static func asinFromUrl(_ url: String) -> String? {
        guard let urlObj = URL(string: url) else {
            return nil
        }

        // Match against common Amazon URL patterns
        let regex = try? NSRegularExpression(
            pattern: "/(?:dp|gp/product)/([A-Z0-9]{10})(?:/|\\?|$)", options: .caseInsensitive)

        if let regex = regex,
            let match = regex.firstMatch(
                in: urlObj.path, options: [],
                range: NSRange(location: 0, length: urlObj.path.utf16.count)) {
            if let range = Range(match.range(at: 1), in: urlObj.path) {
                return String(urlObj.path[range])
            }
        }

        return nil
    }

    /// Checks if a string is a valid ASIN
    /// - Parameter asin: The string to check
    /// - Returns: True if the string is a valid ASIN, false otherwise
    private static func isValidAsin(_ asin: String) -> Bool {
        // Amazon Standard Identification Numbers (ASINs) are always 10 characters long
        // and can contain uppercase letters (A-Z) and numbers (0-9)
        let asinRegex = try? NSRegularExpression(pattern: "^[A-Z0-9]{10}$", options: [])

        guard let asinRegex = asinRegex else {
            return false
        }

        let range = NSRange(location: 0, length: asin.utf16.count)
        return asinRegex.firstMatch(in: asin, options: [], range: range) != nil
    }
}
