import CrossmintCommonTypes
import Foundation
import Utils

public enum EIP712 {
    public struct TypedData: Sendable {
        public let domain: Domain
        public let types: [String: [[String: String]]]
        public let primaryType: String
        public let message: [String: any Sendable]

        public init(
            domain: Domain,
            types: [String: [[String: String]]],
            primaryType: String,
            message: [String: any Sendable]
        ) {
            self.domain = domain
            self.types = types
            self.primaryType = primaryType
            self.message = message
        }

        public var isValid: Bool {
            guard types[primaryType] != nil else { return false }

            return true
        }
    }

    public struct Domain: Sendable {
        public let name: String?
        public let version: String?
        public let chainId: Int?
        public let verifyingContract: String?
        public let salt: String?

        public init(
            name: String? = nil,
            version: String? = nil,
            chainId: Int? = nil,
            verifyingContract: String? = nil,
            salt: String? = nil
        ) {
            self.name = name
            self.version = version
            self.chainId = chainId
            self.verifyingContract = verifyingContract
            self.salt = salt
        }
    }

    public struct Field: Sendable {
        public let name: String
        public let type: String

        public init(name: String, type: String) {
            self.name = name
            self.type = type
        }
    }

    public enum TypeString {
        public static let uint256 = "uint256"
        public static let uint128 = "uint128"
        public static let uint64 = "uint64"
        public static let uint32 = "uint32"
        public static let uint16 = "uint16"
        public static let uint8 = "uint8"

        public static let int256 = "int256"
        public static let int128 = "int128"
        public static let int64 = "int64"
        public static let int32 = "int32"
        public static let int16 = "int16"
        public static let int8 = "int8"

        public static let bytes32 = "bytes32"
        public static let bytes16 = "bytes16"
        public static let bytes8 = "bytes8"
        public static let bytes4 = "bytes4"
        public static let bytes = "bytes"

        public static let address = "address"
        public static let bool = "bool"
        public static let string = "string"

        public static func array(_ elementType: String) -> String {
            return "\(elementType)[]"
        }

        public static func fixedArray(_ elementType: String, size: Int) -> String {
            return "\(elementType)[\(size)]"
        }
    }

    public class Builder {
        private var domain: Domain?
        private var types: [String: [[String: String]]] = [:]
        private var primaryType: String?
        private var message: [String: any Sendable] = [:]

        public init() {}

        @discardableResult
        public func withDomain(_ domain: Domain) -> Builder {
            self.domain = domain
            return self
        }

        @discardableResult
        public func withDomain(
            name: String? = nil,
            version: String? = nil,
            chainId: Int? = nil,
            verifyingContract: String? = nil,
            salt: String? = nil
        ) -> Builder {
            self.domain = Domain(
                name: name,
                version: version,
                chainId: chainId,
                verifyingContract: verifyingContract,
                salt: salt
            )
            return self
        }

        @discardableResult
        public func defineType(_ name: String, fields: [Field]) -> Builder {
            types[name] = fields.map { ["name": $0.name, "type": $0.type] }
            return self
        }

        @discardableResult
        public func defineType(_ name: String, _ closure: (FieldBuilder) -> Void) -> Builder {
            let fieldBuilder = FieldBuilder()
            closure(fieldBuilder)
            let fields = fieldBuilder.build()
            types[name] = fields.map { ["name": $0.name, "type": $0.type] }
            return self
        }

        @discardableResult
        public func defineEIP712Domain(
            includeName: Bool = true,
            includeVersion: Bool = true,
            includeChainId: Bool = true,
            includeVerifyingContract: Bool = true,
            includeSalt: Bool = false
        ) -> Builder {
            var fields: [Field] = []
            if includeName { fields.append(Field(name: "name", type: TypeString.string)) }
            if includeVersion { fields.append(Field(name: "version", type: TypeString.string)) }
            if includeChainId { fields.append(Field(name: "chainId", type: TypeString.uint256)) }
            if includeVerifyingContract { fields.append(Field(name: "verifyingContract", type: TypeString.address)) }
            if includeSalt { fields.append(Field(name: "salt", type: TypeString.bytes32)) }
            return defineType("EIP712Domain", fields: fields)
        }

        @discardableResult
        public func withPrimaryType(_ primaryType: String) -> Builder {
            self.primaryType = primaryType
            return self
        }

        @discardableResult
        public func withMessage(_ message: [String: any Sendable]) -> Builder {
            self.message = message
            return self
        }

        public func build() -> TypedData? {
            guard let domain = domain,
                  let primaryType = primaryType else {
                return nil
            }

            return TypedData(
                domain: domain,
                types: types,
                primaryType: primaryType,
                message: message
            )
        }
    }

    public class FieldBuilder {
        private var fields: [Field] = []

        @discardableResult
        public func field(_ name: String, type: String) -> FieldBuilder {
            fields.append(Field(name: name, type: type))
            return self
        }

        @discardableResult
        public func address(_ name: String) -> FieldBuilder {
            return field(name, type: TypeString.address)
        }

        @discardableResult
        public func uint256(_ name: String) -> FieldBuilder {
            return field(name, type: TypeString.uint256)
        }

        @discardableResult
        public func uint128(_ name: String) -> FieldBuilder {
            return field(name, type: TypeString.uint128)
        }

        @discardableResult
        public func uint64(_ name: String) -> FieldBuilder {
            return field(name, type: TypeString.uint64)
        }

        @discardableResult
        public func uint32(_ name: String) -> FieldBuilder {
            return field(name, type: TypeString.uint32)
        }

        @discardableResult
        public func uint8(_ name: String) -> FieldBuilder {
            return field(name, type: TypeString.uint8)
        }

        @discardableResult
        public func int256(_ name: String) -> FieldBuilder {
            return field(name, type: TypeString.int256)
        }

        @discardableResult
        public func bool(_ name: String) -> FieldBuilder {
            return field(name, type: TypeString.bool)
        }

        @discardableResult
        public func string(_ name: String) -> FieldBuilder {
            return field(name, type: TypeString.string)
        }

        @discardableResult
        public func bytes32(_ name: String) -> FieldBuilder {
            return field(name, type: TypeString.bytes32)
        }

        @discardableResult
        public func bytes(_ name: String) -> FieldBuilder {
            return field(name, type: TypeString.bytes)
        }

        @discardableResult
        public func array(_ name: String, elementType: String) -> FieldBuilder {
            return field(name, type: TypeString.array(elementType))
        }

        @discardableResult
        public func fixedArray(_ name: String, elementType: String, size: Int) -> FieldBuilder {
            return field(name, type: TypeString.fixedArray(elementType, size: size))
        }

        @discardableResult
        public func structType(_ name: String, typeName: String) -> FieldBuilder {
            return field(name, type: typeName)
        }

        func build() -> [Field] {
            return fields
        }
    }

    public enum CommonPatterns {
        public static func permit(
            tokenName: String,
            tokenVersion: String = "1",
            chainId: Int,
            verifyingContract: String,
            owner: String,
            spender: String,
            value: Int,
            nonce: Int,
            deadline: Int
        ) -> TypedData {
            let domain = Domain(
                name: tokenName,
                version: tokenVersion,
                chainId: chainId,
                verifyingContract: verifyingContract
            )

            let types: [String: [[String: String]]] = [
                "EIP712Domain": [
                    ["name": "name", "type": "string"],
                    ["name": "version", "type": "string"],
                    ["name": "chainId", "type": "uint256"],
                    ["name": "verifyingContract", "type": "address"]
                ],
                "Permit": [
                    ["name": "owner", "type": "address"],
                    ["name": "spender", "type": "address"],
                    ["name": "value", "type": "uint256"],
                    ["name": "nonce", "type": "uint256"],
                    ["name": "deadline", "type": "uint256"]
                ]
            ]

            let message: [String: any Sendable] = [
                "owner": owner,
                "spender": spender,
                "value": value,
                "nonce": nonce,
                "deadline": deadline
            ]

            return TypedData(
                domain: domain,
                types: types,
                primaryType: "Permit",
                message: message
            )
        }

        public static func metaTransaction(
            dappName: String,
            dappVersion: String = "1",
            chainId: Int,
            verifyingContract: String,
            from: String,
            to: String,
            value: Int = 0,
            data: String,
            nonce: Int
        ) -> TypedData {
            let domain = Domain(
                name: dappName,
                version: dappVersion,
                chainId: chainId,
                verifyingContract: verifyingContract
            )

            let types: [String: [[String: String]]] = [
                "EIP712Domain": [
                    ["name": "name", "type": "string"],
                    ["name": "version", "type": "string"],
                    ["name": "chainId", "type": "uint256"],
                    ["name": "verifyingContract", "type": "address"]
                ],
                "MetaTransaction": [
                    ["name": "from", "type": "address"],
                    ["name": "to", "type": "address"],
                    ["name": "value", "type": "uint256"],
                    ["name": "data", "type": "bytes"],
                    ["name": "nonce", "type": "uint256"]
                ]
            ]

            let message: [String: any Sendable] = [
                "from": from,
                "to": to,
                "value": value,
                "data": data,
                "nonce": nonce
            ]

            return TypedData(
                domain: domain,
                types: types,
                primaryType: "MetaTransaction",
                message: message
            )
        }
    }
}

extension EIP712.TypedData {
    public func toSignTypedDataRequest(
        chain: Chain,
        signer: (any AdminSignerData)? = nil,
        isSmartWalletSignature: Bool = false
    ) -> SignTypedDataRequest {
        let apiDomain = SignTypedDataRequest.TypedData.Domain(
            name: domain.name ?? "",
            version: domain.version ?? "",
            chainId: domain.chainId ?? 0,
            verifyingContract: domain.verifyingContract ?? "",
            salt: domain.salt
        )

        var encodableMessage: [String: any Encodable] = [:]
        for (key, value) in message {
            switch value {
            case let string as String:
                encodableMessage[key] = string
            case let int as Int:
                encodableMessage[key] = int
            case let bool as Bool:
                encodableMessage[key] = bool
            case let double as Double:
                encodableMessage[key] = double
            case let array as [any Sendable]:
                if let jsonData = try? JSONSerialization.data(withJSONObject: array),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    encodableMessage[key] = jsonString
                }
            case let dict as [String: any Sendable]:
                encodableMessage[key] = AnyCodable(dict)
            default:
                encodableMessage[key] = String(describing: value)
            }
        }

        let apiTypedData = SignTypedDataRequest.TypedData(
            domain: apiDomain,
            types: types,
            primaryType: primaryType,
            message: encodableMessage
        )

        return SignTypedDataRequest(
            params: SignTypedDataRequest.Params(
                typedData: apiTypedData,
                chain: chain,
                signer: signer,
                isSmartWalletSignature: isSmartWalletSignature
            )
        )
    }
}
