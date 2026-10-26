import CrossmintCommonTypes
import CrossmintService
import Foundation
import Testing
import TestsUtils

@testable import Wallet

@Suite("Signer Registration API Errors", .tags(.unit))
struct DefaultWalletServiceTests {
    private let entry = DelegatedSignerEntry(signer: .locator(.device(publicKey: "test-key")))

    private func makeService(status: Int = 200, body: Data) throws -> DefaultWalletService {
        let router = HTTPFixtureRouter()
        router.respond(status: status, body: body)
        let crossmintService = DefaultCrossmintService(
            apiKey: try ApiKey(key: "ck_staging_test123"),
            appIdentifier: "com.crossmint.tests",
            httpClient: router.client
        )
        return DefaultWalletService(crossmintService: crossmintService, jsonCoder: DefaultJSONCoder())
    }

    private func makeService(errorBody: Data) throws -> DefaultWalletService {
        try makeService(status: 400, body: errorBody)
    }

    @Test
    func decodesChainsRegistrationResponse() async throws {
        let body = Data(
            """
            {"chains": {"solana": {"id": "sig1", "status": "success"}}}
            """.utf8
        )
        let service = try makeService(body: body)

        let response = try await service.addSigner(
            entry,
            chainType: .solana,
            chainName: "solana",
            deployImmediately: nil
        )

        #expect(response.chains?["solana"]?.id == "sig1")
    }

    @Test
    func decodesTransactionRegistrationResponse() async throws {
        let body = Data(#"{"transaction": {"id": "tx-123", "status": "awaiting-approval"}}"#.utf8)
        let service = try makeService(body: body)

        let response = try await service.addSigner(
            entry,
            chainType: .solana,
            chainName: "solana",
            deployImmediately: nil
        )

        #expect(response.transaction?.id == "tx-123")
    }

    @Test
    func throwsTypedErrorForDeviceSignerNotSupportedCode() async throws {
        let body = Data(
            """
            {
                "error": true,
                "message": "Device signers are not supported for this provider",
                "code": "DEVICE_SIGNER_NOT_SUPPORTED"
            }
            """.utf8
        )
        let service = try makeService(errorBody: body)

        await #expect {
            _ = try await service.addSigner(entry, chainType: .solana, chainName: "solana", deployImmediately: nil)
        } throws: { error in
            guard case .deviceSignerNotSupported(let message) = error as? WalletError else { return false }
            return message == "Device signers are not supported for this provider"
        }
    }

    @Test
    func usesFallbackMessageWhenErrorBodyOmitsMessage() async throws {
        let body = Data(#"{"error": true, "code": "DEVICE_SIGNER_NOT_SUPPORTED"}"#.utf8)
        let service = try makeService(errorBody: body)

        await #expect {
            _ = try await service.addSigner(entry, chainType: .solana, chainName: "solana", deployImmediately: nil)
        } throws: { error in
            guard case .deviceSignerNotSupported(let message) = error as? WalletError else { return false }
            return message == "Device signers are not supported for this wallet's provider."
        }
    }

    @Test
    func throwsTypedErrorWhenCreateWalletRejectsDeviceSigner() async throws {
        let body = Data(
            """
            {
                "error": true,
                "message": "Device signers are not supported for this provider",
                "code": "DEVICE_SIGNER_NOT_SUPPORTED"
            }
            """.utf8
        )
        let service = try makeService(errorBody: body)
        let params = CreateWalletParams(
            chainType: .solana,
            type: .smart,
            config: .init(
                adminSigner: EmailSignerData(email: "user@example.com"),
                delegatedSigners: [entry]
            )
        )

        await #expect {
            _ = try await service.createWallet(params)
        } throws: { error in
            guard case .deviceSignerNotSupported(let message) = error as? WalletError else { return false }
            return message == "Device signers are not supported for this provider"
        }
    }

    @Test(arguments: [
        "SIGNER_LIMIT_EXCEEDED",
        "DELEGATED_SIGNER_CONFLICT",
        "RECOVERY_ADMIN_SIGNER_CONFLICT",
        "RECOVERY_SIGNER_NOT_ALLOWED",
        "QUORUM_SIGNER_UNSUPPORTED",
        "QUORUM_TOO_FEW_MEMBERS",
        "QUORUM_SIZE_INVALID",
        "QUORUM_THRESHOLD_EXCEEDS_MEMBERS",
        "QUORUM_MEMBER_DUPLICATED",
        "QUORUM_MEMBER_TYPE_NOT_ALLOWED",
        "QUORUM_MEMBER_TYPE_UNSUPPORTED"
    ])
    func throwsTypedErrorWhenCreateWalletRejectsTheRecoveryList(apiCode: String) async throws {
        let body = Data(#"{"error": true, "message": "rejected: \#(apiCode)", "code": "\#(apiCode)"}"#.utf8)
        let service = try makeService(errorBody: body)
        let params = CreateWalletParams(
            chainType: .solana,
            type: .smart,
            config: .init(adminSigner: EmailSignerData(email: "alice@example.com"), delegatedSigners: nil)
        )

        await #expect {
            _ = try await service.createWallet(params)
        } throws: { error in
            guard case .recoveryConfigRejected(let code, let message) = error as? WalletError else { return false }
            return code.rawValue == apiCode && message == "rejected: \(apiCode)"
        }
    }

    @Test
    func usesFallbackMessageWhenRecoveryErrorBodyOmitsMessage() async throws {
        let body = Data(#"{"error": true, "code": "SIGNER_LIMIT_EXCEEDED"}"#.utf8)
        let service = try makeService(errorBody: body)
        let params = CreateWalletParams(
            chainType: .stellar,
            type: .smart,
            config: .init(adminSigner: EmailSignerData(email: "alice@example.com"), delegatedSigners: nil)
        )

        await #expect {
            _ = try await service.createWallet(params)
        } throws: { error in
            guard case .recoveryConfigRejected(let code, let message) = error as? WalletError else { return false }
            return code == .signerLimitExceeded
                && message == "The recovery signer configuration was rejected"
        }
    }

    @Test(arguments: [
        "SOMETHING_ELSE",
        "INVALID_RECOVERY_CONFIG",
        "SIGNER_REQUIRED",
        "RECOVERY_NOT_SUPPORTED_ON_CHAIN"
    ])
    func keepsGenericErrorForCodesTheApiDoesNotDefine(apiCode: String) async throws {
        let body = Data(#"{"error": true, "message": "boom", "code": "\#(apiCode)"}"#.utf8)
        let service = try makeService(errorBody: body)

        await #expect {
            _ = try await service.addSigner(entry, chainType: .solana, chainName: "solana", deployImmediately: nil)
        } throws: { error in
            guard case .walletGeneric = error as? WalletError else { return false }
            return true
        }
    }
}

@Suite("Signer Registration deployImmediately Body", .tags(.unit))
struct DefaultWalletServiceDeployImmediatelyTests {
    private let entry = DelegatedSignerEntry(signer: .locator(.externalWallet(address: "0x456")))
    private let typedSigner = PasskeySignerData(
        id: "pk-id",
        name: "alice",
        publicKey: .init(x: "1", y: "2")
    )
    private let successBody = Data(#"{"chains": {"base-sepolia": {"id": "sig1", "status": "success"}}}"#.utf8)

    private func makeService(recording router: HTTPFixtureRouter) throws -> DefaultWalletService {
        router.respond(body: successBody)
        let crossmintService = DefaultCrossmintService(
            apiKey: try ApiKey(key: "ck_staging_test123"),
            appIdentifier: "com.crossmint.tests",
            httpClient: router.client
        )
        return DefaultWalletService(crossmintService: crossmintService, jsonCoder: DefaultJSONCoder())
    }

    private func decodedBody(_ data: Data?) throws -> [String: Any] {
        let data = try #require(data)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return try #require(json)
    }

    @Test
    func sendsTheApproverWhenNamed() async throws {
        let router = HTTPFixtureRouter()
        let service = try makeService(recording: router)

        _ = try await service.addSigner(
            entry,
            chainType: .solana,
            chainName: "solana",
            deployImmediately: nil,
            approver: .email("alice@example.com")
        )

        let json = try decodedBody(router.lastRequest?.httpBody)
        #expect(json["approver"] as? String == "email:alice@example.com")
    }

    @Test
    func omitsTheApproverWhenAbsent() async throws {
        let router = HTTPFixtureRouter()
        let service = try makeService(recording: router)

        _ = try await service.addSigner(entry, chainType: .solana, chainName: "solana", deployImmediately: nil)

        let json = try decodedBody(router.lastRequest?.httpBody)
        #expect(json["approver"] == nil)
    }

    @Test
    func sendsDeployImmediatelyTrueByDefaultForEVM() async throws {
        let router = HTTPFixtureRouter()
        let service = try makeService(recording: router)

        _ = try await service.addSigner(entry, chainType: .evm, chainName: "base-sepolia", deployImmediately: true)

        let json = try decodedBody(router.lastRequest?.httpBody)
        #expect(json["deployImmediately"] as? Bool == true)
    }

    @Test
    func sendsDeployImmediatelyFalseWhenOverridden() async throws {
        let router = HTTPFixtureRouter()
        let service = try makeService(recording: router)

        _ = try await service.addSigner(entry, chainType: .evm, chainName: "base-sepolia", deployImmediately: false)

        let json = try decodedBody(router.lastRequest?.httpBody)
        #expect(json["deployImmediately"] as? Bool == false)
    }

    @Test
    func omitsDeployImmediatelyForSolana() async throws {
        let router = HTTPFixtureRouter()
        let service = try makeService(recording: router)

        _ = try await service.addSigner(entry, chainType: .solana, chainName: "solana", deployImmediately: true)

        let json = try decodedBody(router.lastRequest?.httpBody)
        #expect(json["deployImmediately"] == nil)
        #expect(json["chain"] == nil)
    }

    @Test
    func omitsDeployImmediatelyForStellar() async throws {
        let router = HTTPFixtureRouter()
        let service = try makeService(recording: router)

        _ = try await service.addSigner(entry, chainType: .stellar, chainName: "stellar", deployImmediately: true)

        let json = try decodedBody(router.lastRequest?.httpBody)
        #expect(json["deployImmediately"] == nil)
    }

    @Test
    func sendsDeployImmediatelyTrueByDefaultForEVMTypedSigner() async throws {
        let router = HTTPFixtureRouter()
        let service = try makeService(recording: router)

        _ = try await service.registerTypedSigner(
            typedSigner,
            chainType: .evm,
            chainName: "base-sepolia",
            deployImmediately: true
        )

        let json = try decodedBody(router.lastRequest?.httpBody)
        #expect(json["deployImmediately"] as? Bool == true)
    }

    @Test
    func sendsDeployImmediatelyFalseWhenOverriddenForTypedSigner() async throws {
        let router = HTTPFixtureRouter()
        let service = try makeService(recording: router)

        _ = try await service.registerTypedSigner(
            typedSigner,
            chainType: .evm,
            chainName: "base-sepolia",
            deployImmediately: false
        )

        let json = try decodedBody(router.lastRequest?.httpBody)
        #expect(json["deployImmediately"] as? Bool == false)
    }

    @Test(arguments: [ChainType.solana, .stellar])
    func omitsDeployImmediatelyForNonEVMTypedSigner(chainType: ChainType) async throws {
        let router = HTTPFixtureRouter()
        let service = try makeService(recording: router)

        _ = try await service.registerTypedSigner(
            typedSigner,
            chainType: chainType,
            chainName: "chain",
            deployImmediately: true
        )

        let json = try decodedBody(router.lastRequest?.httpBody)
        #expect(json["deployImmediately"] == nil)
    }
}

@Suite("Signer Registration Signer Body", .tags(.unit))
struct DefaultWalletServiceSignerBodyTests {
    private let successBody = Data(#"{"chains": {"base-sepolia": {"id": "sig1", "status": "success"}}}"#.utf8)

    private func makeService(recording router: HTTPFixtureRouter) throws -> DefaultWalletService {
        router.respond(body: successBody)
        let crossmintService = DefaultCrossmintService(
            apiKey: try ApiKey(key: "ck_staging_test123"),
            appIdentifier: "com.crossmint.tests",
            httpClient: router.client
        )
        return DefaultWalletService(crossmintService: crossmintService, jsonCoder: DefaultJSONCoder())
    }

    @Test
    func encodesLocatorSignerAsPlainString() async throws {
        let router = HTTPFixtureRouter()
        let service = try makeService(recording: router)
        let entry = DelegatedSignerEntry(signer: .locator(.externalWallet(address: "0x456")))

        _ = try await service.addSigner(entry, chainType: .evm, chainName: "base-sepolia", deployImmediately: true)

        let data = try #require(router.lastRequest?.httpBody)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["signer"] as? String == "external-wallet:0x456")
    }

    @Test
    func encodesDeviceSignerWithPublicKeyAndName() async throws {
        let router = HTTPFixtureRouter()
        let service = try makeService(recording: router)
        let rawKey = Data([0x04]) + Data((0..<64).map { UInt8($0) })
        let publicKey = try #require(DevicePublicKey(publicKeyBase64: rawKey.base64EncodedString()))
        let entry = DelegatedSignerEntry(signer: .device(publicKey: publicKey, name: "My iPhone"))

        _ = try await service.addSigner(entry, chainType: .evm, chainName: "base-sepolia", deployImmediately: true)

        let data = try #require(router.lastRequest?.httpBody)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let signer = try #require(json["signer"] as? [String: Any])
        #expect(signer["type"] as? String == "device")
        #expect(signer["name"] as? String == "My iPhone")
        let encodedKey = try #require(signer["publicKey"] as? [String: String])
        #expect(encodedKey["x"] == publicKey.x)
        #expect(encodedKey["y"] == publicKey.y)
    }
}

/// Lets a test capture a value from inside the `@Sendable` HTTPClient fetch closure.
final class SendableBox<Value>: @unchecked Sendable {
    var value: Value

    init(_ value: Value) {
        self.value = value
    }
}
