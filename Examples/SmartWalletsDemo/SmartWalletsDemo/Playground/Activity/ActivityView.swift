//
//  ActivityView.swift
//  SmartWalletsDemo
//

import CrossmintClient
import SwiftUI

struct ActivityView: View {
    let wallet: Wallet?
    let chain: SupportedChain

    @State private var transfers: [Transfer] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading activity…")
                } else if let error = errorMessage {
                    ContentUnavailableView(
                        "Error",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else if transfers.isEmpty {
                    ContentUnavailableView(
                        "No Activity",
                        systemImage: "list.bullet",
                        description: Text("No transfers found for this wallet.")
                    )
                } else {
                    List(transfers) { transfer in
                        TransferRow(transfer: transfer, walletAddress: wallet?.address ?? "")
                    }
                    .refreshable { await loadTransfers() }
                }
            }
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task { await loadTransfers() }
    }

    private func loadTransfers() async {
        guard let wallet else { return }
        isLoading = true
        errorMessage = nil
        do {
            let result = try await wallet.listTransfers(tokens: chain.balanceCurrencies)
            transfers = result.transfers
        } catch {
            errorMessage = error.userMessage
        }
        isLoading = false
    }
}
