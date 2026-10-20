//
//  PreparedQuorumSection.swift
//  SmartWalletsDemo
//

import CrossmintClient
import SwiftUI

struct PreparedQuorumSection: View {
    let transaction: WalletTransaction
    let labelIdentifier: String

    var body: some View {
        Section {
            Label("Prepared for the quorum", systemImage: "person.3")
                .fontWeight(.medium)
                .accessibilityIdentifier(labelIdentifier)
            QuorumProgressRows(transaction: transaction)
            CopyButton(value: transaction.id, lineLimit: 2)
        }
    }
}
