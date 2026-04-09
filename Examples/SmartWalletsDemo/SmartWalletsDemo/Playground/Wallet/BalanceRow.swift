//
//  BalanceRow.swift
//  SmartWalletsDemo
//

import SwiftUI

struct BalanceRow: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        LabeledContent("Balance") {
            if appState.isLoadingBalance {
                ProgressView()
                    .scaleEffect(0.7)
            } else {
                Text(appState.formattedBalance)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .animation(.default, value: appState.formattedBalance)
            }
        }
    }
}
