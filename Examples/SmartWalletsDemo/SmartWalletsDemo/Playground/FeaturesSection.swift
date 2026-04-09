//
//  FeaturesSection.swift
//  SmartWalletsDemo
//

import SwiftUI

struct FeaturesSection: View {
    @Environment(AppState.self) private var appState
    @Binding var showSigners: Bool
    @Binding var showTransfer: Bool
    @Binding var showActivity: Bool
    @Binding var showSigning: Bool

    var body: some View {
        Section("Features") {
            Button { showSigners = true } label: {
                Label("Signers", systemImage: "person.badge.key")
            }
            .disabled(appState.wallet == nil)

            Button { showTransfer = true } label: {
                Label("Transfer", systemImage: "arrow.up.circle")
            }
            .disabled(appState.wallet == nil)

            Button { showActivity = true } label: {
                Label("Activity", systemImage: "list.bullet")
            }
            .disabled(appState.wallet == nil)

            if appState.selectedChain.supportsMessageSigning {
                Button { showSigning = true } label: {
                    Label("Signing", systemImage: "signature")
                }
                .disabled(appState.wallet == nil)
            }
        }
        .tint(.primary)
    }
}
