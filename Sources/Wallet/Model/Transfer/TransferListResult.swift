//
//  TransferListResult.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 21/01/26.
//

import Foundation

/// The result of fetching wallet transfer activity.
///
/// This struct contains an array of ``Transfer`` events representing the wallet's
/// transaction history. The transfers are sorted by timestamp in descending order
/// (most recent first).
///
/// ## Basic Usage
///
/// ```swift
/// let result = try await wallet.listTransfers(tokens: [.eth, .usdc])
///
/// for transfer in result.transfers {
///     print("\(transfer.timestamp): \(transfer.amount) \(transfer.tokenSymbol ?? "")")
/// }
/// ```
///
/// ## Pagination
///
/// The result includes cursor-based pagination support. Use ``hasNextPage`` and
/// ``hasPreviousPage`` to check if more results are available.
///
/// > Note: Pagination is reserved for future use. Currently, all available
/// > transfers are returned in a single response.
public struct TransferListResult: Sendable {
    /// The array of transfer events.
    ///
    /// Transfers are sorted by timestamp in descending order (most recent first).
    /// This array may be empty if the wallet has no transfer history for the
    /// specified tokens.
    public let transfers: [Transfer]

    /// Cursor for fetching the next page of results.
    ///
    /// This will be `nil` if there are no more results available.
    /// Reserved for future pagination support.
    public let nextCursor: String?

    /// Cursor for fetching the previous page of results.
    ///
    /// This will be `nil` if this is the first page of results.
    /// Reserved for future pagination support.
    public let previousCursor: String?

    public init(
        transfers: [Transfer],
        nextCursor: String?,
        previousCursor: String?
    ) {
        self.transfers = transfers
        self.nextCursor = nextCursor
        self.previousCursor = previousCursor
    }

    /// Indicates whether more results are available after this page.
    ///
    /// Returns `true` if ``nextCursor`` is not `nil`.
    public var hasNextPage: Bool {
        nextCursor != nil
    }

    /// Indicates whether results exist before this page.
    ///
    /// Returns `true` if ``previousCursor`` is not `nil`.
    public var hasPreviousPage: Bool {
        previousCursor != nil
    }
}
