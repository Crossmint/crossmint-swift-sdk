//
//  PlaygroundView.swift
//  SmartWalletsDemo
//

import CrossmintClient
import SwiftUI

struct PlaygroundView: View {
    @Binding var authenticationStatus: AuthenticationStatus?
    @State private var appState = AppState()
    @State private var presentedSheet: SheetType?

    private var email: String? {
        guard case .authenticated(let email, _, _) = authenticationStatus else { return nil }
        return email
    }

    var body: some View {
        NavigationStack {
            List {
                WalletSectionView(email: email)
                FeaturesSection(presentedSheet: $presentedSheet)
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
                        .accessibilityIdentifier("logout-button")
                    } label: {
                        Image(systemName: "person.circle")
                    }
                    .accessibilityIdentifier("logout-button")
                }
            }
        }
        .environment(appState)
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .signers:
                SignersView().environment(appState)
            case .transfer:
                TransferView { await appState.fetchBalance() }.environment(appState)
            case .activity:
                ActivityView().environment(appState)
            case .signing:
                SigningView().environment(appState)
            }
        }
        .task {
            if let email {
                await appState.loadWallet(email: email)
            }
        }
    }

    private func signOut() async {
        await CrossmintSDK.shared.logout()
        authenticationStatus = .nonAuthenticated
    }
}

#Preview {
    PlaygroundView(
        authenticationStatus: .constant(.authenticated(email: "test@example.com", jwt: "jwt", secret: "secret"))
    )
}
