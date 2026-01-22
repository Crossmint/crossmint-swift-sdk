//
//  Transfer.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 21/01/26.
//

import CrossmintCommonTypes
import Foundation

/// Represents a wallet activity event such as a token transfer or NFT transfer.
///
/// Use this model to display transaction history in your application. Each transfer
/// contains information about the sender, recipient, token, amount, and timestamp.
///
/// ## Determining Transfer Direction
///
/// Use ``isOutgoing(from:)`` or ``isIncoming(to:)`` to determine if a transfer
/// was sent from or received by a specific wallet address:
///
/// ```swift
/// let result = try await wallet.listTransfers(tokens: [.eth, .usdc])
/// for transfer in result.transfers {
///     if transfer.isOutgoing(from: wallet.address) {
///         print("Sent \(transfer.amount) \(transfer.tokenSymbol ?? "tokens")")
///     } else {
///         print("Received \(transfer.amount) \(transfer.tokenSymbol ?? "tokens")")
///     }
/// }
/// ```
///
public struct Transfer: Sendable, Hashable, Equatable, Identifiable {
    /// Unique identifier for the transfer.
    ///
    /// This is the same as ``transactionHash`` and can be used to look up
    /// the transaction on a blockchain explorer.
    public var id: String {
        transactionHash
    }

    /// The type of activity.
    ///
    /// Common values include:
    /// - `"TRANSFER"` - A standard token transfer
    /// - `"NFT_TRANSFER"` - An NFT transfer
    public let type: String

    /// The blockchain address that sent the transfer.
    public let fromAddress: String

    /// The blockchain address that received the transfer.
    public let toAddress: String

    /// The unique hash identifying this transaction on the blockchain.
    ///
    /// This can be used to look up the transaction on a blockchain explorer.
    public let transactionHash: String

    /// The symbol of the token involved in the transfer.
    ///
    /// For example: `"ETH"`, `"USDC"`, `"SOL"`. May be `nil` for some transfer types.
    public let tokenSymbol: String?

    /// The human-readable amount of tokens transferred.
    ///
    /// This value has already been adjusted for the token's decimals.
    /// For example, if 1.5 USDC was transferred, this will be `1.5`.
    public let amount: Decimal

    /// The raw amount string as returned by the API.
    ///
    /// Use this if you need the exact string representation for display or further processing.
    public let rawAmount: String

    /// The date and time when the transfer occurred.
    public let timestamp: Date

    /// The mint hash for NFT transfers.
    ///
    /// This identifies the specific NFT that was transferred. Will be `nil` for
    /// fungible token transfers.
    public let mintHash: String?

    public init(
        type: String,
        fromAddress: String,
        toAddress: String,
        transactionHash: String,
        tokenSymbol: String?,
        amount: Decimal,
        rawAmount: String,
        timestamp: Date,
        mintHash: String?
    ) {
        self.type = type
        self.fromAddress = fromAddress
        self.toAddress = toAddress
        self.transactionHash = transactionHash
        self.tokenSymbol = tokenSymbol
        self.amount = amount
        self.rawAmount = rawAmount
        self.timestamp = timestamp
        self.mintHash = mintHash
    }

    /// Determines if this transfer was sent from the given wallet address.
    ///
    /// - Parameter walletAddress: The wallet address to check against. The comparison is case-insensitive.
    /// - Returns: `true` if this transfer was sent from the specified address, `false` otherwise.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let transfer = result.transfers.first!
    /// if transfer.isOutgoing(from: wallet.address) {
    ///     print("You sent \(transfer.amount) \(transfer.tokenSymbol ?? "")")
    /// }
    /// ```
    public func isOutgoing(from walletAddress: String) -> Bool {
        fromAddress.lowercased() == walletAddress.lowercased()
    }

    /// Determines if this transfer was received by the given wallet address.
    ///
    /// - Parameter walletAddress: The wallet address to check against. The comparison is case-insensitive.
    /// - Returns: `true` if this transfer was received by the specified address, `false` otherwise.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let transfer = result.transfers.first!
    /// if transfer.isIncoming(to: wallet.address) {
    ///     print("You received \(transfer.amount) \(transfer.tokenSymbol ?? "")")
    /// }
    /// ```
    public func isIncoming(to walletAddress: String) -> Bool {
        toAddress.lowercased() == walletAddress.lowercased()
    }
}

// MARK: - Mapping

extension Transfer {
    static func map(_ apiModel: ActivityEventApiModel) -> Transfer {
        let timestamp = Date(timeIntervalSince1970: apiModel.timestamp)

        return Transfer(
            type: apiModel.type,
            fromAddress: apiModel.fromAddress,
            toAddress: apiModel.toAddress,
            transactionHash: apiModel.transactionHash,
            tokenSymbol: apiModel.tokenSymbol,
            amount: Decimal(string: apiModel.amount) ?? 0,
            rawAmount: apiModel.amount,
            timestamp: timestamp,
            mintHash: apiModel.mintHash
        )
    }
}
