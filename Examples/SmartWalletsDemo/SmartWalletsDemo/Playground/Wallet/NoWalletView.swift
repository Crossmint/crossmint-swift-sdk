//
//  NoWalletView.swift
//  SmartWalletsDemo
//

import CrossmintClient
import SwiftUI

struct NoWalletView: View {
    @Environment(AppState.self) private var appState
    let email: String?

    @State private var extraRecovery: [RecoverySignerDraft] = []

    private var canCreate: Bool {
        !appState.isCreatingWallet && extraRecovery.allSatisfy(\.isComplete)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("No \(appState.selectedChain.chainDisplayName) wallet found.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if appState.selectedChain.supportsRecoveryList, let email {
                RecoverySignerListEditor(primaryLocator: "email:\(email)", drafts: $extraRecovery)
            }
            Button {
                Task {
                    if let email {
                        await appState.createWallet(email: email, extraRecovery: extraRecovery)
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
            .disabled(!canCreate)
        }
        .padding(.vertical, 4)
    }
}
