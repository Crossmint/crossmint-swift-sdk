//
//  TransferRow.swift
//  SmartWalletsDemo
//

import CrossmintClient
import SwiftUI

struct TransferRow: View {
    let transfer: Transfer

    private var isOutgoing: Bool { transfer.type == .outgoing }

    private var counterparty: String {
        let address = isOutgoing ? transfer.toAddress : transfer.fromAddress
        return formatAddress(address)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isOutgoing ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .foregroundStyle(isOutgoing ? .red : .green)
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text(isOutgoing ? "Sent to \(counterparty)" : "Received from \(counterparty)")
                    .font(.subheadline)
                    .lineLimit(1)
                Text(transfer.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(isOutgoing ? "-" : "+")\(transfer.amount.formatted()) \(transfer.tokenSymbol ?? "")")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(isOutgoing ? .red : .green)
            }
        }
        .padding(.vertical, 2)
    }

    private func formatAddress(_ address: String) -> String {
        guard address.count > 10 else { return address }
        return "\(address.prefix(6))…\(address.suffix(4))"
    }
}
