import CrossmintCommonTypes
import CrossmintService
import Foundation
import Testing

@testable import Http
@testable import Wallet

@Suite("Signer Registration API Errors", .tags(.unit))
struct DefaultWalletServiceTests {
    private let entry = DelegatedSignerEntry(signer: "device:test-key")

    private func makeService(httpClient: HTTPClient) throws -> DefaultWalletService {
        let crossmintService = DefaultCrossmintService(
            apiKey: try ApiKey(key: "ck_staging_test123"),
            appIdentifier: "com.crossmint.tests",
            httpClient: httpClient
        )
        return DefaultWalletService(crossmintService: crossmintService, jsonCoder: DefaultJSONCoder())
    }

    private func makeService(errorBody: Data) throws -> DefaultWalletService {
        try makeService(
            httpClient: HTTPClient(fetch: { _ throws(NetworkError) in
                throw NetworkError.badRequest(errorBody)
            })
        )
    }

    @Test
    func decodesChainsRegistrationResponse() async throws {
        let body = Data(
            """
            {"chains": {"solana": {"id": "sig1", "status": "success"}}}
            """.utf8
        )
        let service = try makeService(
            httpClient: HTTPClient(fetch: { _ throws(NetworkError) in (body, URLResponse()) })
        )

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
        let service = try makeService(
            httpClient: HTTPClient(fetch: { _ throws(NetworkError) in (body, URLResponse()) })
        )

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
            {"error": true, "message": "Device signers are not supported for this provider", "code": "DEVICE_SIGNER_NOT_SUPPORTED"}
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
    func keepsGenericErrorForOtherCodes() async throws {
        let body = Data(#"{"error": true, "message": "boom", "code": "SOMETHING_ELSE"}"#.utf8)
        let service = try makeService(errorBody: body)

        await #expect {
            _ = try await service.addSigner(entry, chainType: .solana, chainName: "solana", deployImmediately: nil)
        } throws: { error in
            if case .deviceSignerNotSupported = error as? WalletError { return false }
            return true
        }
    }
}

@Suite("Signer Registration deployImmediately Body", .tags(.unit))
struct DefaultWalletServiceDeployImmediatelyTests {
    private let entry = DelegatedSignerEntry(signer: "external-wallet:0x456")
    private let typedSigner = PasskeySignerData(
        id: "pk-id",
        name: "alice",
        publicKey: .init(x: "1", y: "2")
    )
    private let successBody = Data(#"{"chains": {"base-sepolia": {"id": "sig1", "status": "success"}}}"#.utf8)

    private func makeService(capturingBodyInto capturedBody: SendableBox<Data?>) throws -> DefaultWalletService {
        let crossmintService = DefaultCrossmintService(
            apiKey: try ApiKey(key: "ck_staging_test123"),
            appIdentifier: "com.crossmint.tests",
            httpClient: HTTPClient(fetch: { [successBody] request throws(NetworkError) in
                capturedBody.value = request.httpBody
                return (successBody, URLResponse())
            })
        )
        return DefaultWalletService(crossmintService: crossmintService, jsonCoder: DefaultJSONCoder())
    }

    private func decodedBody(_ data: Data?) throws -> [String: Any] {
        let data = try #require(data)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return try #require(json)
    }

    @Test
    func sendsDeployImmediatelyTrueByDefaultForEVM() async throws {
        let capturedBody = SendableBox<Data?>(nil)
        let service = try makeService(capturingBodyInto: capturedBody)

        _ = try await service.addSigner(entry, chainType: .evm, chainName: "base-sepolia", deployImmediately: true)

        let json = try decodedBody(capturedBody.value)
        #expect(json["deployImmediately"] as? Bool == true)
    }

    @Test
    func sendsDeployImmediatelyFalseWhenOverridden() async throws {
        let capturedBody = SendableBox<Data?>(nil)
        let service = try makeService(capturingBodyInto: capturedBody)

        _ = try await service.addSigner(entry, chainType: .evm, chainName: "base-sepolia", deployImmediately: false)

        let json = try decodedBody(capturedBody.value)
        #expect(json["deployImmediately"] as? Bool == false)
    }

    @Test
    func omitsDeployImmediatelyForSolana() async throws {
        let capturedBody = SendableBox<Data?>(nil)
        let service = try makeService(capturingBodyInto: capturedBody)

        _ = try await service.addSigner(entry, chainType: .solana, chainName: "solana", deployImmediately: true)

        let json = try decodedBody(capturedBody.value)
        #expect(json["deployImmediately"] == nil)
        #expect(json["chain"] == nil)
    }

    @Test
    func omitsDeployImmediatelyForStellar() async throws {
        let capturedBody = SendableBox<Data?>(nil)
        let service = try makeService(capturingBodyInto: capturedBody)

        _ = try await service.addSigner(entry, chainType: .stellar, chainName: "stellar", deployImmediately: true)

        let json = try decodedBody(capturedBody.value)
        #expect(json["deployImmediately"] == nil)
    }

    @Test
    func sendsDeployImmediatelyTrueByDefaultForEVMTypedSigner() async throws {
        let capturedBody = SendableBox<Data?>(nil)
        let service = try makeService(capturingBodyInto: capturedBody)

        _ = try await service.registerTypedSigner(
            typedSigner,
            chainType: .evm,
            chainName: "base-sepolia",
            deployImmediately: true
        )

        let json = try decodedBody(capturedBody.value)
        #expect(json["deployImmediately"] as? Bool == true)
    }

    @Test
    func sendsDeployImmediatelyFalseWhenOverriddenForTypedSigner() async throws {
        let capturedBody = SendableBox<Data?>(nil)
        let service = try makeService(capturingBodyInto: capturedBody)

        _ = try await service.registerTypedSigner(
            typedSigner,
            chainType: .evm,
            chainName: "base-sepolia",
            deployImmediately: false
        )

        let json = try decodedBody(capturedBody.value)
        #expect(json["deployImmediately"] as? Bool == false)
    }

    @Test(arguments: [ChainType.solana, .stellar])
    func omitsDeployImmediatelyForNonEVMTypedSigner(chainType: ChainType) async throws {
        let capturedBody = SendableBox<Data?>(nil)
        let service = try makeService(capturingBodyInto: capturedBody)

        _ = try await service.registerTypedSigner(
            typedSigner,
            chainType: chainType,
            chainName: "chain",
            deployImmediately: true
        )

        let json = try decodedBody(capturedBody.value)
        #expect(json["deployImmediately"] == nil)
    }
}

/// Lets a test capture a value from inside the `@Sendable` HTTPClient fetch closure.
final class SendableBox<Value>: @unchecked Sendable {
    var value: Value

    init(_ value: Value) {
        self.value = value
    }
}
