//
//  NoWalletView.swift
//  SmartWalletsDemo
//

import SwiftUI

struct NoWalletView: View {
    @Environment(AppState.self) private var appState
    let email: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("No \(appState.selectedChain.chainDisplayName) wallet found.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                Task {
                    if let email {
                        await appState.createWallet(email: email)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    if appState.isCreatingWallet {
                        ProgressView().scaleEffect(0.8)
                    }
                    Text(appState.isCreatingWallet ? "Creating Wallet…" : "Create Wallet")
                        .fontWeight(.medium)
                }
            }
            .disabled(appState.isCreatingWallet)
        }
        .padding(.vertical, 4)
    }
}
