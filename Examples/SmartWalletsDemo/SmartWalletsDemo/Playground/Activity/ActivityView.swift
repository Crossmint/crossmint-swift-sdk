//
//  ActivityView.swift
//  SmartWalletsDemo
//

import CrossmintClient
import SwiftUI

struct ActivityView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var transfers: [Transfer] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

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
                    List(Array(transfers.enumerated()), id: \.element.id) { offset, transfer in
                        TransferRow(transfer: transfer)
                            .accessibilityIdentifier("activity-item-\(offset)")
                    }
                    .accessibilityIdentifier("activity-list")
                    .refreshable { await loadTransfers(isRefresh: true) }
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

    private func loadTransfers(isRefresh: Bool = false) async {
        guard let wallet = appState.wallet else { return }
        if !isRefresh { isLoading = true }
        errorMessage = nil
        do {
            let result = try await wallet.listTransfers(tokens: appState.selectedChain.balanceCurrencies)
            transfers = result.transfers
        } catch {
            errorMessage = error.userMessage
        }
        isLoading = false
    }
}
