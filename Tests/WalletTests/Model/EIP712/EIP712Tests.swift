import CrossmintCommonTypes
import Foundation
import Testing
import TestsUtils
import Utils
@testable import Wallet

// swiftlint:disable:next type_body_length
struct EIP712Tests {

    @Test
    func testTypedDataCreation() throws {
        let domain = EIP712.Domain(
            name: "TestApp",
            version: "1",
            chainId: 1,
            verifyingContract: "0x1234567890123456789012345678901234567890"
        )

        let types: [String: [[String: String]]] = [
            "Message": [
                ["name": "from", "type": "address"],
                ["name": "to", "type": "address"],
                ["name": "amount", "type": "uint256"]
            ]
        ]

        let message: [String: any Sendable] = [
            "from": "0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
            "to": "0xBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB",
            "amount": 1000000
        ]

        let typedData = EIP712.TypedData(
            domain: domain,
            types: types,
            primaryType: "Message",
            message: message
        )

        #expect(typedData.isValid == true)
        #expect(typedData.domain.name == "TestApp")
        #expect(typedData.domain.version == "1")
        #expect(typedData.domain.chainId == 1)
        #expect(typedData.primaryType == "Message")
    }

    @Test
    func testDomainWithOptionalFields() throws {
        let domainWithAllFields = EIP712.Domain(
            name: "App",
            version: "2",
            chainId: 137,
            verifyingContract: "0xContract",
            salt: "0xSalt"
        )

        #expect(domainWithAllFields.name == "App")
        #expect(domainWithAllFields.version == "2")
        #expect(domainWithAllFields.chainId == 137)
        #expect(domainWithAllFields.verifyingContract == "0xContract")
        #expect(domainWithAllFields.salt == "0xSalt")

        let emptyDomain = EIP712.Domain()

        #expect(emptyDomain.name == nil)
        #expect(emptyDomain.version == nil)
        #expect(emptyDomain.chainId == nil)
        #expect(emptyDomain.verifyingContract == nil)
        #expect(emptyDomain.salt == nil)
    }

    @Test
    func testTypedDataBuilder() throws {
        let typedData = EIP712.Builder()
            .withDomain(
                name: "TestApp",
                version: "1",
                chainId: 1,
                verifyingContract: "0x1234567890123456789012345678901234567890"
            )
            .defineEIP712Domain()
            .defineType("Message") { builder in
                builder
                    .address("from")
                    .address("to")
                    .uint256("amount")
            }
            .withPrimaryType("Message")
            .withMessage([
                "from": "0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
                "to": "0xBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB",
                "amount": 1000000
            ])
            .build()

        #expect(typedData != nil)
        #expect(typedData?.isValid == true)
        #expect(typedData?.domain.name == "TestApp")
        #expect(typedData?.primaryType == "Message")
        #expect(typedData?.types["Message"] != nil)
        #expect(typedData?.types["EIP712Domain"] != nil) // Still there because defineEIP712Domain was called
    }

    @Test
    func testFieldBuilder() throws {
        let builder = EIP712.FieldBuilder()
            .address("owner")
            .uint256("balance")
            .bool("active")
            .string("name")
            .bytes32("hash")
            .array("tokens", elementType: "address")
            .fixedArray("values", elementType: "uint256", size: 10)
            .structType("user", typeName: "User")

        let fields = builder.build()

        #expect(fields.count == 8)
        #expect(fields[0].name == "owner")
        #expect(fields[0].type == "address")
        #expect(fields[1].type == "uint256")
        #expect(fields[2].type == "bool")
        #expect(fields[3].type == "string")
        #expect(fields[4].type == "bytes32")
        #expect(fields[5].type == "address[]")
        #expect(fields[6].type == "uint256[10]")
        #expect(fields[7].type == "User")
    }

    @Test
    func testTypeStringHelpers() throws {
        #expect(EIP712.TypeString.uint256 == "uint256")
        #expect(EIP712.TypeString.address == "address")
        #expect(EIP712.TypeString.bool == "bool")
        #expect(EIP712.TypeString.string == "string")
        #expect(EIP712.TypeString.bytes32 == "bytes32")

        #expect(EIP712.TypeString.array("uint256") == "uint256[]")
        #expect(EIP712.TypeString.fixedArray("address", size: 5) == "address[5]")
    }

    @Test
    func testCommonPatternPermit() throws {
        let permit = EIP712.CommonPatterns.permit(
            tokenName: "USDC",
            chainId: 1,
            verifyingContract: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
            owner: "0x1111111111111111111111111111111111111111",
            spender: "0x2222222222222222222222222222222222222222",
            value: 1000000,
            nonce: 0,
            deadline: 1234567890
        )

        #expect(permit.isValid == true)
        #expect(permit.domain.name == "USDC")
        #expect(permit.domain.version == "1")
        #expect(permit.domain.chainId == 1)
        #expect(permit.primaryType == "Permit")
        #expect(permit.message["owner"] as? String == "0x1111111111111111111111111111111111111111")
        #expect(permit.message["value"] as? Int == 1000000)
    }

    @Test
    func testCommonPatternMetaTransaction() throws {
        let metaTx = EIP712.CommonPatterns.metaTransaction(
            dappName: "MyDApp",
            chainId: 137,
            verifyingContract: "0x3333333333333333333333333333333333333333",
            from: "0x4444444444444444444444444444444444444444",
            to: "0x5555555555555555555555555555555555555555",
            data: "0xabcdef",
            nonce: 42
        )

        #expect(metaTx.isValid == true)
        #expect(metaTx.domain.name == "MyDApp")
        #expect(metaTx.primaryType == "MetaTransaction")
        #expect(metaTx.message["from"] as? String == "0x4444444444444444444444444444444444444444")
        #expect(metaTx.message["nonce"] as? Int == 42)
    }

    struct MockAdminSignerData: AdminSignerData {
        let type: AdminSignerDataType
        let locatorId: String
    }

    @Test
    func testToSignTypedDataRequest() throws {
        let domain = EIP712.Domain(
            name: "TestApp",
            version: "1",
            chainId: 1,
            verifyingContract: "0x1234567890123456789012345678901234567890"
        )

        let types: [String: [[String: String]]] = [
            "EIP712Domain": [
                ["name": "name", "type": "string"],
                ["name": "version", "type": "string"],
                ["name": "chainId", "type": "uint256"],
                ["name": "verifyingContract", "type": "address"]
            ],
            "Message": [
                ["name": "text", "type": "string"]
            ]
        ]

        let message: [String: any Sendable] = [
            "text": "Hello, World!"
        ]

        let typedData = EIP712.TypedData(
            domain: domain,
            types: types,
            primaryType: "Message",
            message: message
        )

        let signer = MockAdminSignerData(
            type: .passkey,
            locatorId: "test-signer"
        )

        let request = typedData.toSignTypedDataRequest(
            chain: .ethereum,
            signer: signer,
            isSmartWalletSignature: true
        )

        #expect(request.type == "typed-data")
        #expect(request.params.chain == .ethereum)
        #expect(request.params.signer?.locator == "passkey:test-signer")
        #expect(request.params.isSmartWalletSignature == true)
        #expect(request.params.typedData.primaryType == "Message")
        #expect(request.params.typedData.domain.name == "TestApp")
    }

    @Test
    func testToSignTypedDataRequestWithOptionalDomain() throws {
        let domain = EIP712.Domain(
            name: nil,
            version: nil,
            chainId: nil,
            verifyingContract: nil
        )

        let types: [String: [[String: String]]] = [
            "EIP712Domain": [],
            "Test": [
                ["name": "value", "type": "string"]
            ]
        ]

        let typedData = EIP712.TypedData(
            domain: domain,
            types: types,
            primaryType: "Test",
            message: ["value": "test"]
        )

        let request = typedData.toSignTypedDataRequest(
            chain: .polygon,
            signer: nil,
            isSmartWalletSignature: false
        )

        #expect(request.params.typedData.domain.name == "")
        #expect(request.params.typedData.domain.version == "")
        #expect(request.params.typedData.domain.chainId == 0)
        #expect(request.params.typedData.domain.verifyingContract == "")
        #expect(request.params.typedData.domain.salt == nil)
    }

    @Test
    func testToSignTypedDataRequestWithComplexMessage() throws {
        let nestedObject: [String: any Sendable] = [
            "name": "Nested",
            "value": 123
        ]

        let message: [String: any Sendable] = [
            "string": "Hello",
            "number": 42,
            "boolean": true,
            "nested": nestedObject,
            "array": [1, 2, 3] as [any Sendable]
        ]

        let typedData = EIP712.TypedData(
            domain: EIP712.Domain(name: "Test"),
            types: ["EIP712Domain": [], "Complex": []],
            primaryType: "Complex",
            message: message
        )

        let request = typedData.toSignTypedDataRequest(chain: .ethereum)

        let encodedMessage = request.params.typedData.message
        #expect(encodedMessage["string"] as? String == "Hello")
        #expect(encodedMessage["number"] as? Int == 42)
        #expect(encodedMessage["boolean"] as? Bool == true)

        #expect(encodedMessage["nested"] != nil)
        let arrayString = encodedMessage["array"] as? String
        #expect(arrayString == "[1,2,3]")
    }

    @Test
    // swiftlint:disable:next function_body_length
    func testRealWorldEtherMailExample() throws {
        let domain = EIP712.Domain(
            name: "Ether Mail",
            version: "1",
            chainId: 1,
            verifyingContract: "0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC"
        )

        let types: [String: [[String: String]]] = [
            "EIP712Domain": [
                ["name": "name", "type": "string"],
                ["name": "version", "type": "string"],
                ["name": "chainId", "type": "uint256"],
                ["name": "verifyingContract", "type": "address"]
            ],
            "Person": [
                ["name": "name", "type": "string"],
                ["name": "wallet", "type": "address"]
            ],
            "Mail": [
                ["name": "from", "type": "Person"],
                ["name": "to", "type": "Person"],
                ["name": "contents", "type": "string"]
            ]
        ]

        let message: [String: any Sendable] = [
            "from": [
                "name": "Cow",
                "wallet": "0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826"
            ],
            "to": [
                "name": "Bob",
                "wallet": "0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB"
            ],
            "contents": "Hello, Bob!"
        ]

        let typedData = EIP712.TypedData(
            domain: domain,
            types: types,
            primaryType: "Mail",
            message: message
        )

        #expect(typedData.isValid == true)
        #expect(typedData.primaryType == "Mail")
        #expect(typedData.domain.name == "Ether Mail")
        #expect(typedData.domain.version == "1")
        #expect(typedData.domain.chainId == 1)
        #expect(typedData.domain.verifyingContract == "0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC")

        #expect(typedData.types["EIP712Domain"] != nil)
        #expect(typedData.types["EIP712Domain"]?.count == 4)
        #expect(typedData.types["Person"] != nil)
        #expect(typedData.types["Person"]?.count == 2)
        #expect(typedData.types["Mail"] != nil)
        #expect(typedData.types["Mail"]?.count == 3)

        let fromPerson = typedData.message["from"] as? [String: String]
        #expect(fromPerson?["name"] == "Cow")
        #expect(fromPerson?["wallet"] == "0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826")

        let toPerson = typedData.message["to"] as? [String: String]
        #expect(toPerson?["name"] == "Bob")
        #expect(toPerson?["wallet"] == "0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB")

        #expect(typedData.message["contents"] as? String == "Hello, Bob!")

        let signRequest = typedData.toSignTypedDataRequest(chain: .ethereum)

        #expect(signRequest.type == "typed-data")
        #expect(signRequest.params.typedData.primaryType == "Mail")
        #expect(signRequest.params.typedData.domain.name == "Ether Mail")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        let jsonData = try encoder.encode(signRequest)
        // swiftlint:disable:next force_unwrapping
        let jsonString = String(data: jsonData, encoding: .utf8)!

        #expect(jsonString.contains("\"primaryType\" : \"Mail\""))
        #expect(jsonString.contains("\"name\" : \"Ether Mail\""))
        #expect(jsonString.contains("\"contents\" : \"Hello, Bob!\""))

        let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        let params = jsonObject?["params"] as? [String: Any]
        let typedDataJson = params?["typedData"] as? [String: Any]
        let messageJson = typedDataJson?["message"] as? [String: Any]

        #expect(messageJson != nil)
        #expect(messageJson?["contents"] as? String == "Hello, Bob!")

        #expect(messageJson?["from"] != nil)
        #expect(messageJson?["to"] != nil)
    }

    @Test
    // swiftlint:disable:next function_body_length
    func testParseSignatureResponseWithNullValues() throws {
        // Test parsing the actual signature response JSON
        let response: TypedDataSignatureResponse = try GetFromFile.getModelFrom(
            fileName: "CreateSignatureAwaitingApproval",
            bundle: Bundle.module
        )

        // Verify basic response fields
        #expect(response.id == "93694d0f-74df-4541-a655-86dc8ccb176c")
        #expect(response.type == "typed-data")
        #expect(response.status == "awaiting-approval")
        #expect(response.chainType == "evm")
        #expect(response.walletType == "smart")

        // Verify params
        #expect(response.params.chain == "base-sepolia")
        #expect(response.params.isSmartWalletSignature == true)

        // Verify signer
        #expect(response.params.signer.locator == "passkey:v-Qxh--c2nOkUyBYJHRaXCwSOJw")

        // Verify typed data
        let typedData = response.params.typedData
        #expect(typedData.domain.name == "Ether Mail")
        #expect(typedData.domain.version == "1")
        #expect(typedData.domain.chainId == 1)
        #expect(typedData.domain.verifyingContract == "0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC")
        #expect(typedData.domain.salt == nil)

        // Verify types
        #expect(typedData.types.count == 2)
        #expect(typedData.types["Mail"] != nil)
        #expect(typedData.types["Person"] != nil)

        // Verify Mail type
        let mailType = typedData.types["Mail"]
        #expect(mailType?.count == 1)
        #expect(mailType?.first?.name == "contents")
        #expect(mailType?.first?.type == "string")

        // Verify Person type
        let personType = typedData.types["Person"]
        #expect(personType?.count == 2)

        // Verify primary type
        #expect(typedData.primaryType == "Mail")

        // Verify message with null values
        // The message field is AnyCodable, so we need to handle it properly
        // AnyCodable wraps values, including dictionaries
        let messageValue = typedData.message.value

        if let messageDict = messageValue as? [String: AnyCodable] {
            // Values are wrapped in AnyCodable
            #expect(messageDict["contents"]?.value as? String == "Hello, Bob!")

            // Check null handling - () represents null in AnyCodable
            if let fromValue = messageDict["from"]?.value {
                // AnyCodable represents null as ()
                #expect(fromValue is () || fromValue as? String == nil)
            }
            if let toValue = messageDict["to"]?.value {
                // AnyCodable represents null as ()
                #expect(toValue is () || toValue as? String == nil)
            }
        } else if let messageDict = messageValue as? [String: Any] {
            // Fallback for direct dictionary
            #expect(messageDict["contents"] as? String == "Hello, Bob!")

            if let fromValue = messageDict["from"] {
                #expect(fromValue is NSNull || fromValue as? String == nil)
            }
            if let toValue = messageDict["to"] {
                #expect(toValue is NSNull || toValue as? String == nil)
            }
        } else {
            Issue.record("Message should be a dictionary, got: \(String(describing: messageValue))")
        }

        // Verify approvals
        #expect(response.approvals.pending.count == 1)
        #expect(response.approvals.submitted.isEmpty)

        let pendingApproval = response.approvals.pending.first
        #expect(pendingApproval?.signer.locator == "passkey:v-Qxh--c2nOkUyBYJHRaXCwSOJw")
        #expect(pendingApproval?.message == "0x849a233d43cc67e60b07bf5623e0901d0ab2a706d07821e78c2e60ec7bbc5a19")
    }

    @Test
    func testEtherMailExampleWithoutEIP712Domain() throws {
        let data = EIP712.Builder()
            .withDomain(
                EIP712.Domain(
                    name: "Ether Mail",
                    version: "1",
                    chainId: 1,
                    verifyingContract: "0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC"
                )
            )
            .defineType("Person") { builder in
                builder.string("name").address("wallet")
            }
            .defineType("Mail") { builder in
                builder.string("contents")
            }
            .withPrimaryType("Mail")
            .withMessage(
                [
                    "from": [
                        "name": "Cow",
                        "wallet": "0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826"
                    ],
                    "to": [
                        "name": "Bob",
                        "wallet": "0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB"
                    ],
                    "contents": "Hello, Bob!"
                ]
            )
            .build()

        guard let typedData = data else {
            Issue.record("Data is nil, but is expected to be non-nil")
            return
        }

        #expect(typedData.isValid == true)
        #expect(typedData.primaryType == "Mail")
        #expect(typedData.types["EIP712Domain"] == nil)
        #expect(typedData.types["Person"] != nil)
        #expect(typedData.types["Mail"] != nil)

        let signRequest = typedData.toSignTypedDataRequest(chain: .ethereum)
        #expect(signRequest.params.typedData.primaryType == "Mail")
        #expect(signRequest.params.typedData.types["EIP712Domain"] == nil)
    }
}
