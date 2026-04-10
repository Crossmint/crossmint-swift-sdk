//
//  FeaturesSection.swift
//  SmartWalletsDemo
//

import SwiftUI

enum SheetType: Identifiable, Hashable {
    case signers, transfer, activity, signing
    var id: Self { self }
}

struct FeaturesSection: View {
    @Environment(AppState.self) private var appState
    @Binding var presentedSheet: SheetType?

    var body: some View {
        Section("Features") {
            Button { presentedSheet = .signers } label: {
                Label("Signers", systemImage: "person.badge.key")
            }
            .disabled(appState.wallet == nil)

            Button { presentedSheet = .transfer } label: {
                Label("Transfer", systemImage: "arrow.up.circle")
            }
            .disabled(appState.wallet == nil)

            Button { presentedSheet = .activity } label: {
                Label("Activity", systemImage: "list.bullet")
            }
            .disabled(appState.wallet == nil)

            if appState.selectedChain.supportsMessageSigning {
                Button { presentedSheet = .signing } label: {
                    Label("Signing", systemImage: "signature")
                }
                .disabled(appState.wallet == nil)
            }
        }
        .tint(.primary)
    }
}
