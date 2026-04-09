//
//  WalletSectionView.swift
//  SmartWalletsDemo
//

import SwiftUI

struct WalletSectionView: View {
    @Environment(AppState.self) private var appState
    let email: String?

    var body: some View {
        Section {
            if appState.isLoadingWallet {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Loading wallet…")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } else if appState.walletNotFound {
                NoWalletView(email: email)
            } else if let error = appState.walletErrorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("Retry") {
                        Task {
                            if let email {
                                await appState.loadWallet(email: email)
                            }
                        }
                    }
                    .font(.footnote)
                }
                .padding(.vertical, 4)
            } else if appState.wallet != nil {
                BalanceRow()
                AddressRow()
                if let email {
                    LabeledContent("Owner") {
                        Text(email).foregroundStyle(.secondary)
                    }
                }
                LabeledContent("Network") {
                    Text(appState.selectedChain.chainDisplayName).foregroundStyle(.secondary)
                }
                AddFundsRow()
            }
        } header: {
            Text("Wallet")
        }
    }
}
