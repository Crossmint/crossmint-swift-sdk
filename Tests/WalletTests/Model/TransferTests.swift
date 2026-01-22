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
    @Test("Will decode an activity response with events")
    func willDecodeActivityResponse() async throws {
        let response: TransferListApiModel = try GetFromFile.getModelFrom(
            fileName: "ListTransfersResponse",
            bundle: Bundle.module
        )

        #expect(response.events.count == 3)
    }

    @Test("Will map outgoing transfer correctly")
    func willMapOutgoingTransfer() async throws {
        let response: TransferListApiModel = try GetFromFile.getModelFrom(
            fileName: "ListTransfersResponse",
            bundle: Bundle.module
        )

        let walletAddress = "0x1234567890123456789012345678901234567890"
        let transfer = Transfer.map(response.events[0])

        #expect(transfer.isOutgoing(from: walletAddress) == true)
        #expect(transfer.isIncoming(to: walletAddress) == false)
        #expect(transfer.fromAddress == walletAddress)
        #expect(transfer.toAddress == "0x0987654321098765432109876543210987654321")
        #expect(transfer.tokenSymbol == "USDC")
        #expect(transfer.amount == Decimal(string: "10.5"))
        #expect(transfer.rawAmount == "10.5")
        #expect(transfer.type == "TRANSFER")
        #expect(transfer.transactionHash == "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890")
        #expect(transfer.mintHash == nil)
    }

    @Test("Will map incoming transfer correctly")
    func willMapIncomingTransfer() async throws {
        let response: TransferListApiModel = try GetFromFile.getModelFrom(
            fileName: "ListTransfersResponse",
            bundle: Bundle.module
        )

        let walletAddress = "0x1234567890123456789012345678901234567890"
        let transfer = Transfer.map(response.events[1])

        #expect(transfer.isOutgoing(from: walletAddress) == false)
        #expect(transfer.isIncoming(to: walletAddress) == true)
        #expect(transfer.fromAddress == "0x0987654321098765432109876543210987654321")
        #expect(transfer.toAddress == walletAddress)
        #expect(transfer.tokenSymbol == "ETH")
        #expect(transfer.amount == Decimal(string: "0.05"))
        #expect(transfer.type == "TRANSFER")
    }

    @Test("Will map transfer with mint hash (NFT) correctly")
    func willMapNFTTransfer() async throws {
        let response: TransferListApiModel = try GetFromFile.getModelFrom(
            fileName: "ListTransfersResponse",
            bundle: Bundle.module
        )

        let transfer = Transfer.map(response.events[2])

        #expect(transfer.type == "NFT_TRANSFER")
        #expect(transfer.mintHash == "0xnftmintha5h000000000000000000000000000000000000000000000000000")
        #expect(transfer.tokenSymbol == "USDC")
        #expect(transfer.amount == Decimal(string: "25.00"))
    }

    @Test("Will parse timestamp from Unix time")
    func willParseTimestamp() async throws {
        let response: TransferListApiModel = try GetFromFile.getModelFrom(
            fileName: "ListTransfersResponse",
            bundle: Bundle.module
        )

        let transfer = Transfer.map(response.events[0])

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: transfer.timestamp
        )

        #expect(components.year == 2024)
        #expect(components.month == 1)
        #expect(components.day == 15)
        #expect(components.hour == 10)
        #expect(components.minute == 50)
        #expect(components.second == 0)
    }

    @Test("Will parse timestamp with fractional seconds")
    func willParseTimestampWithFractionalSeconds() async throws {
        let response: TransferListApiModel = try GetFromFile.getModelFrom(
            fileName: "ListTransfersResponse",
            bundle: Bundle.module
        )

        let transfer = Transfer.map(response.events[1])

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
        #expect(components.minute == 35)
        #expect(components.second == 30)
    }

    @Test("TransferListResult pagination helpers work correctly")
    func transferListResultPaginationHelpers() async throws {
        let response: TransferListApiModel = try GetFromFile.getModelFrom(
            fileName: "ListTransfersResponse",
            bundle: Bundle.module
        )

        let resultWithNextPage = TransferListResult(
            transfers: response.events.map { Transfer.map($0) },
            nextCursor: "some-cursor",
            previousCursor: nil
        )

        #expect(resultWithNextPage.hasNextPage == true)
        #expect(resultWithNextPage.hasPreviousPage == false)
        #expect(resultWithNextPage.transfers.count == 3)

        let resultWithNoCursors = TransferListResult(
            transfers: response.events.map { Transfer.map($0) },
            nextCursor: nil,
            previousCursor: nil
        )

        #expect(resultWithNoCursors.hasNextPage == false)
        #expect(resultWithNoCursors.hasPreviousPage == false)
    }

    @Test("Transfer is Identifiable with transactionHash as id")
    func transferIsIdentifiable() async throws {
        let response: TransferListApiModel = try GetFromFile.getModelFrom(
            fileName: "ListTransfersResponse",
            bundle: Bundle.module
        )

        let transfer = Transfer.map(response.events[0])

        #expect(transfer.id == "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890")
    }
}
