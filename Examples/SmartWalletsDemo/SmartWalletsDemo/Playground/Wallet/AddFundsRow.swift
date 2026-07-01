//
//  AddFundsRow.swift
//  SmartWalletsDemo
//

import CrossmintClient
import SwiftUI

struct AddFundsRow: View {
    @Environment(AppState.self) private var appState
    @State private var isAddingFunds = false
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        if appState.wallet != nil {
            Button {
                Task { await addFunds() }
            } label: {
                HStack(spacing: 8) {
                    if isAddingFunds {
                        ProgressView().scaleEffect(0.8)
                    }
                    Text(isAddingFunds ? "Adding Funds…" : "Add Test Funds")
                }
            }
            .disabled(isAddingFunds)
            .accessibilityIdentifier("fund-button")
            .alert("Error", isPresented: $showError) {
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func addFunds() async {
        guard let wallet = appState.wallet else { return }
        isAddingFunds = true
        do {
            try await wallet.fund(token: appState.selectedChain.fundToken, amount: 10)
            await appState.fetchBalance()
        } catch {
            errorMessage = error.userMessage
            showError = true
        }
        isAddingFunds = false
    }
}
