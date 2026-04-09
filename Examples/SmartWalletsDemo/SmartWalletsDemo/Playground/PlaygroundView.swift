//
//  PlaygroundView.swift
//  SmartWalletsDemo
//

import CrossmintClient
import SwiftUI

struct PlaygroundView: View {
    @Binding var authenticationStatus: AuthenticationStatus?
    @State private var appState = AppState()

    @State private var showSigners = false
    @State private var showTransfer = false
    @State private var showActivity = false
    @State private var showSigning = false
    private var email: String? {
        guard case .authenticated(let email, _, _) = authenticationStatus else { return nil }
        return email
    }

    var body: some View {
        NavigationStack {
            List {
                WalletSectionView(email: email)
                FeaturesSection(
                    showSigners: $showSigners,
                    showTransfer: $showTransfer,
                    showActivity: $showActivity,
                    showSigning: $showSigning
                )
            }
            .refreshable {
                if let email {
                    await appState.loadWallet(email: email)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ChainPickerMenu(selectedChain: appState.selectedChain) { chain in
                        Task {
                            if let email {
                                await appState.switchChain(chain, email: email)
                            }
                        }
                    }
                    .tint(.primary)
                }

                ToolbarItem(placement: .principal) {
                    Label("crossmint", image: "crossmint-icon")
                        .labelStyle(.titleAndIcon)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if let email { Text(email) }
                        Divider()
                        Button("Sign Out", role: .destructive) {
                            Task { await signOut() }
                        }
                    } label: {
                        Image(systemName: "person.circle")
                    }
                }
            }
        }
        .environment(appState)
        .sheet(isPresented: $showSigners) {
            SignersView()
                .environment(appState)
        }
        .sheet(isPresented: $showTransfer) {
            TransferView(wallet: appState.wallet, chain: appState.selectedChain, balance: appState.balance) {
                await appState.fetchBalance()
            }
        }
        .sheet(isPresented: $showActivity) {
            ActivityView(wallet: appState.wallet, chain: appState.selectedChain)
        }
        .sheet(isPresented: $showSigning) {
            SigningView(wallet: appState.wallet as? EVMWallet)
        }
        .task {
            if let email {
                await appState.loadWallet(email: email)
            }
        }
    }

    private func signOut() async {
        try? await crossmintAuthManager.logout()
        try? await CrossmintSDK.shared.logout()
        authenticationStatus = .nonAuthenticated
    }
}

#Preview {
    PlaygroundView(
        authenticationStatus: .constant(.authenticated(email: "test@example.com", jwt: "jwt", secret: "secret"))
    )
}
