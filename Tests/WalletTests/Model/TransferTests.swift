//
//  TransferTests.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 21/01/26.
//

import CrossmintCommonTypes
import Foundation
import Testing
import TestsUtils

@testable import Wallet

struct TransferTests {
    @Test("Will decode a list transfers response with pagination")
    func willDecodeListTransfersResponse() async throws {
        let response: TransferListApiModel = try GetFromFile.getModelFrom(
            fileName: "ListTransfersResponse",
            bundle: Bundle.module
        )

        #expect(response.nextCursor == "eyJsYXN0SWQiOiIxMjM0NTY3ODkwIn0=")
        #expect(response.previousCursor == nil)
        #expect(response.data.count == 3)
    }

    @Test("Will map outgoing transfer correctly")
    func willMapOutgoingTransfer() async throws {
        let response: TransferListApiModel = try GetFromFile.getModelFrom(
            fileName: "ListTransfersResponse",
            bundle: Bundle.module
        )

        let walletAddress = "0x1234567890123456789012345678901234567890"
        let transfer = Transfer.map(response.data[0])

        #expect(transfer.type == "outgoing")
        #expect(transfer.isOutgoing(from: walletAddress) == true)
        #expect(transfer.isIncoming(to: walletAddress) == false)
        #expect(transfer.fromAddress == walletAddress)
        #expect(transfer.toAddress == "0x0987654321098765432109876543210987654321")
        #expect(transfer.tokenSymbol == "USDC")
        #expect(transfer.amount == Decimal(string: "10.5"))
        #expect(transfer.rawAmount == "10.5")
        #expect(transfer.transactionHash == "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890")
    }

    @Test("Will map incoming transfer correctly")
    func willMapIncomingTransfer() async throws {
        let response: TransferListApiModel = try GetFromFile.getModelFrom(
            fileName: "ListTransfersResponse",
            bundle: Bundle.module
        )

        let walletAddress = "0x1234567890123456789012345678901234567890"
        let transfer = Transfer.map(response.data[1])

        #expect(transfer.type == "incoming")
        #expect(transfer.isOutgoing(from: walletAddress) == false)
        #expect(transfer.isIncoming(to: walletAddress) == true)
        #expect(transfer.fromAddress == "0x0987654321098765432109876543210987654321")
        #expect(transfer.toAddress == walletAddress)
        #expect(transfer.tokenSymbol == "ETH")
        #expect(transfer.amount == Decimal(string: "0.05"))
    }

    @Test("Will parse ISO8601 date with fractional seconds")
    func willParseDateWithFractionalSeconds() async throws {
        let response: TransferListApiModel = try GetFromFile.getModelFrom(
            fileName: "ListTransfersResponse",
            bundle: Bundle.module
        )

        let transfer = Transfer.map(response.data[1])

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: transfer.timestamp
        )

        #expect(components.year == 2024)
        #expect(components.month == 1)
        #expect(components.day == 14)
        #expect(components.hour == 8)
        #expect(components.minute == 15)
        #expect(components.second == 30)
    }

    @Test("Will parse ISO8601 date without fractional seconds")
    func willParseDateWithoutFractionalSeconds() async throws {
        let response: TransferListApiModel = try GetFromFile.getModelFrom(
            fileName: "ListTransfersResponse",
            bundle: Bundle.module
        )

        let transfer = Transfer.map(response.data[2])

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: transfer.timestamp
        )

        #expect(components.year == 2024)
        #expect(components.month == 1)
        #expect(components.day == 13)
        #expect(components.hour == 14)
        #expect(components.minute == 0)
        #expect(components.second == 0)
    }

    @Test("TransferListResult pagination helpers work correctly")
    func transferListResultPaginationHelpers() async throws {
        let response: TransferListApiModel = try GetFromFile.getModelFrom(
            fileName: "ListTransfersResponse",
            bundle: Bundle.module
        )

        let result = TransferListResult(
            transfers: response.data.map { Transfer.map($0) },
            nextCursor: response.nextCursor,
            previousCursor: response.previousCursor
        )

        #expect(result.hasNextPage == true)
        #expect(result.hasPreviousPage == false)
        #expect(result.transfers.count == 3)
    }

    @Test("Transfer is Identifiable with txId as id")
    func transferIsIdentifiable() async throws {
        let response: TransferListApiModel = try GetFromFile.getModelFrom(
            fileName: "ListTransfersResponse",
            bundle: Bundle.module
        )

        let transfer = Transfer.map(response.data[0])

        #expect(transfer.id == "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890")
    }
}
