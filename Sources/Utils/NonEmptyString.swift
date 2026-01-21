import Foundation

@dynamicMemberLookup
// swiftlint:disable:next line_length
public struct NonEmptyString: Equatable, Hashable, Codable, CustomStringConvertible, CustomDebugStringConvertible, ExpressibleByStringLiteral, ExpressibleByStringInterpolation, LosslessStringConvertible {
    let value: String

    public init?(_ string: String) {
        guard !string.isEmpty else { return nil }
        self.value = string
    }

    public init(stringLiteral value: String) {
        precondition(!value.isEmpty, "NonEmptyString cannot be initialized with an empty string literal")
        self.value = value
    }

    public init(stringInterpolation: DefaultStringInterpolation) {
        // swiftlint:disable:next compiler_protocol_init
        let string = String(stringInterpolation: stringInterpolation)
        precondition(!string.isEmpty, "NonEmptyString cannot be initialized with an empty string interpolation")
        self.value = string
    }

    public var description: String {
        return value
    }

    public var debugDescription: String {
        return "NonEmptyString(\"\(value)\")"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard !string.isEmpty else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode empty string as NonEmptyString"
            )
        }
        self.value = string
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }

    public subscript<T>(dynamicMember keyPath: KeyPath<String, T>) -> T {
        return value[keyPath: keyPath]
    }

    public subscript<T>(dynamicMember keyPath: WritableKeyPath<String, T>) -> T {
        return value[keyPath: keyPath]
    }
}

extension NonEmptyString: Comparable {
    public static func < (lhs: NonEmptyString, rhs: NonEmptyString) -> Bool {
        return lhs.value < rhs.value
    }
}

extension NonEmptyString {
    public static func == (lhs: NonEmptyString, rhs: String) -> Bool {
        return lhs.value == rhs
    }

    public static func == (lhs: String, rhs: NonEmptyString) -> Bool {
        return lhs == rhs.value
    }

    public static func != (lhs: NonEmptyString, rhs: String) -> Bool {
        return lhs.value != rhs
    }

    public static func != (lhs: String, rhs: NonEmptyString) -> Bool {
        return lhs != rhs.value
    }

    public static func + (lhs: NonEmptyString, rhs: NonEmptyString) -> NonEmptyString {
        // swiftlint:disable:next force_unwrapping
        return NonEmptyString(lhs.value + rhs.value)!
    }

    public static func + (lhs: NonEmptyString, rhs: String) -> String {
        return lhs.value + rhs
    }

    public static func + (lhs: String, rhs: NonEmptyString) -> String {
        return lhs + rhs.value
    }

    public static func += (lhs: inout NonEmptyString, rhs: NonEmptyString) {
        // swiftlint:disable:next force_unwrapping
        lhs = NonEmptyString(lhs.value + rhs.value)!
    }

    public static func += (lhs: inout NonEmptyString, rhs: String) {
        if let newValue = NonEmptyString(lhs.value + rhs) {
            lhs = newValue
        }
    }
}

extension NonEmptyString {
    public var asString: String {
        return value
    }

    public var stringValue: String {
        return value
    }

    public func map(_ transform: (String) -> String) -> NonEmptyString? {
        return NonEmptyString(transform(value))
    }

    public func flatMap(_ transform: (String) -> NonEmptyString?) -> NonEmptyString? {
        return transform(value)
    }
}

extension String {
    public var asNonEmptyString: NonEmptyString? {
        return NonEmptyString(self)
    }
}

extension NonEmptyString: Collection {
    public typealias Index = String.Index
    public typealias Element = Character

    public var startIndex: String.Index {
        return value.startIndex
    }

    public var endIndex: String.Index {
        return value.endIndex
    }

    public func index(after i: String.Index) -> String.Index {
        return value.index(after: i)
    }

    public subscript(position: String.Index) -> Character {
        return value[position]
    }
}

extension NonEmptyString: BidirectionalCollection {
    public func index(before i: String.Index) -> String.Index {
        return value.index(before: i)
    }
}

extension NonEmptyString: RangeReplaceableCollection {
    public init() {
        self.value = " "
    }

    public mutating func replaceSubrange<C>(_ subrange: Range<String.Index>, with newElements: C)
        where C: Collection, Character == C.Element {
        var newValue = value
        newValue.replaceSubrange(subrange, with: newElements)
        if !newValue.isEmpty {
            // swiftlint:disable:next force_unwrapping
            self = NonEmptyString(newValue)!
        }
    }
}

extension NonEmptyString {
    public func hasPrefix(_ prefix: String) -> Bool {
        return value.hasPrefix(prefix)
    }

    public func hasSuffix(_ suffix: String) -> Bool {
        return value.hasSuffix(suffix)
    }

    public func lowercased() -> NonEmptyString {
        // swiftlint:disable:next force_unwrapping
        return NonEmptyString(value.lowercased())!
    }

    public func uppercased() -> NonEmptyString {
        // swiftlint:disable:next force_unwrapping
        return NonEmptyString(value.uppercased())!
    }

    public func trimmingCharacters(in set: CharacterSet) -> NonEmptyString? {
        return NonEmptyString(value.trimmingCharacters(in: set))
    }

    public var count: Int {
        return value.count
    }

    public var isEmpty: Bool {
        return false
    }
}

extension NonEmptyString {
    public func components(separatedBy separator: String) -> [String] {
        return value.components(separatedBy: separator)
    }

    public func replacingOccurrences(of target: String, with replacement: String) -> NonEmptyString? {
        return NonEmptyString(value.replacingOccurrences(of: target, with: replacement))
    }

    public func contains(_ other: String) -> Bool {
        return value.contains(other)
    }

    public func range(of searchString: String) -> Range<String.Index>? {
        return value.range(of: searchString)
    }
}

extension NonEmptyString {
    public func hasPrefix<S: StringProtocol>(_ prefix: S) -> Bool {
        return value.hasPrefix(prefix)
    }

    public func hasSuffix<S: StringProtocol>(_ suffix: S) -> Bool {
        return value.hasSuffix(suffix)
    }

    public func dropFirst(_ k: Int = 1) -> String {
        return String(value.dropFirst(k))
    }

    public func dropLast(_ k: Int = 1) -> String {
        return String(value.dropLast(k))
    }

    public func prefix(_ maxLength: Int) -> String {
        return String(value.prefix(maxLength))
    }

    public func suffix(_ maxLength: Int) -> String {
        return String(value.suffix(maxLength))
    }

    public func split(
        separator: Character, maxSplits: Int = Int.max, omittingEmptySubsequences: Bool = true
    ) -> [String] {
        return value.split(
            separator: separator,
            maxSplits: maxSplits,
            omittingEmptySubsequences: omittingEmptySubsequences
        ).map(String.init)
    }

    public var utf8: String.UTF8View {
        return value.utf8
    }

    public var utf16: String.UTF16View {
        return value.utf16
    }

    public var unicodeScalars: String.UnicodeScalarView {
        return value.unicodeScalars
    }
}
