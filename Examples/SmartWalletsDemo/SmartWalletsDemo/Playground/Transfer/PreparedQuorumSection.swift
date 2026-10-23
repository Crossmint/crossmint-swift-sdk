//
//  PreparedQuorumSection.swift
//  SmartWalletsDemo
//

import CrossmintClient
import SwiftUI

struct PreparedQuorumSection: View {
    let transactionID: String
    let transaction: WalletTransaction?
    let labelIdentifier: String

    var body: some View {
        Section {
            Label("Waiting for the quorum", systemImage: "person.3")
                .fontWeight(.medium)
                .accessibilityIdentifier(labelIdentifier)
            if let transaction {
                QuorumProgressRows(transaction: transaction)
            }
            CopyButton(value: transactionID, lineLimit: 2)
        }
    }
}
