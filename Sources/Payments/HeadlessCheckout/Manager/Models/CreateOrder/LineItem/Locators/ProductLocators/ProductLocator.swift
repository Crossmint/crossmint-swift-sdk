import Foundation

public struct ProductLocator: Codable, Sendable, CustomStringConvertible {
    /// Enumeration of supported product locator types
    private enum ProductLocatorType: Sendable, Codable {
        case amazon(AmazonProductLocator)
    }
    private let type: ProductLocatorType
    public init(amazonLocator: AmazonProductLocator) {
        self.type = .amazon(amazonLocator)
    }

    /// Throws initializer that parses a string into a ProductLocator
    /// - Parameter stringValue: The string to parse
    /// - Throws: ProductLocatorError if the string is not a valid product locator
    public init(from stringValue: String) throws(ProductLocatorError) {
        // Try to parse as Amazon product locator
        do {
            let amazonLocator = try AmazonProductLocator(from: stringValue)
            self.init(amazonLocator: amazonLocator)
        } catch let error as AmazonProductLocatorError {
            throw ProductLocatorError.invalidAmazonProductLocator(error)
        } catch {
            throw ProductLocatorError.invalidProductLocator
        }
    }

    public var amazon: AmazonProductLocator? {
        if case .amazon(let amazonLocator) = type {
            return amazonLocator
        }
        return nil
    }

    public var description: String {
        switch type {
        case .amazon(let amazonLocator):
            return amazonLocator.description
        }
    }
}

// MARK: - Codable Implementation

extension ProductLocator {
    public init(from decoder: Decoder) throws {
        let container: any SingleValueDecodingContainer = try decoder.singleValueContainer()
        if container.decodeNil() {
            throw DecodingError.valueNotFound(
                String.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected a product locator string but found null"
                )
            )
        }

        let stringValue = try container.decode(String.self)
        try self.init(from: stringValue)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.description)
    }
}
