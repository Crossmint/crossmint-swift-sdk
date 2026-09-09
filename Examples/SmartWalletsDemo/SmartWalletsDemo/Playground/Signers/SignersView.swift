//
//  SignersView.swift
//  SmartWalletsDemo
//

import CrossmintClient
import SwiftUI

struct SignersView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var showAddSigner = false
    @State private var removingSignerLocator: String?
    @State private var isLoadingSigners = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false

    private var isRemovingSigner: Bool { removingSignerLocator != nil }

    let email: String?

    var body: some View {
        NavigationStack {
            List {
                if appState.wallet == nil, let email {
                    pendingRecoverySections(email: email)
                } else {
                    walletSections()
                }
            }
            .accessibilityIdentifier("signers-list")
            .navigationTitle("Signers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .disabled(isRemovingSigner || appState.isCreatingWallet)
                }
            }
            .alert(alertTitle, isPresented: $showAlert) {
            } message: {
                Text(alertMessage)
            }
            .task(id: appState.wallet?.address) {
                await loadSigners()
            }
        }
        .interactiveDismissDisabled(isRemovingSigner || appState.isCreatingWallet)
        .sheet(isPresented: $showAddSigner, onDismiss: { Task { await loadSigners() } }) {
            AddSignerSheet()
                .environment(appState)
        }
        .otpSheet()
    }

    @ViewBuilder
    private func pendingRecoverySections(email: String) -> some View {
        Section {
            SignerRow(locator: "email:\(email)", canRemove: false, onSelect: {})
            ForEach(appState.pendingRecovery) { draft in
                SignerRow(
                    locator: draft.locator,
                    canRemove: true,
                    onSelect: {},
                    onRemove: { appState.pendingRecovery.removeAll { $0.id == draft.id } }
                )
            }
        } header: {
            Text("Recovery")
        } footer: {
            Text("Each recovery signer can authorize on its own once the wallet is created.")
        }

        Section {
            Button {
                showAddSigner = true
            } label: {
                Label("Add Signer…", systemImage: "plus.circle")
            }
            .accessibilityIdentifier("signers-add-button")
        }

        Section {
            Button {
                Task { await appState.createWallet(email: email) }
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
            .accessibilityIdentifier("recovery-create-wallet-button")
            if let error = appState.walletErrorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .font(.footnote)
            }
        }
    }

    @ViewBuilder
    private func walletSections() -> some View {
        recoverySection()

        Section("Signers") {
            if appState.signers.isEmpty && !isLoadingSigners {
                ContentUnavailableView(
                    "No Signers",
                    systemImage: "person.badge.key",
                    description: Text("No signers are registered on this wallet.")
                )
            } else {
                ForEach(Array(appState.signers.enumerated()), id: \.element.locator) { index, item in
                    SignerRow(
                        index: index,
                        locator: item.locator,
                        status: item.status.rawValue,
                        isRemoving: removingSignerLocator == item.locator,
                        canRemove: true,
                        onSelect: {},
                        onRemove: { Task { await removeSigner(locator: item.locator) } }
                    )
                }
            }
        }

        Section {
            Button {
                showAddSigner = true
            } label: {
                Label("Add Signer…", systemImage: "plus.circle")
            }
            .disabled(appState.wallet == nil)
            .accessibilityIdentifier("signers-add-button")
        }
    }

    @ViewBuilder
    private func recoverySection() -> some View {
        let locators = appState.recoveryLocators
        if !locators.isEmpty {
            Section("Recovery") {
                ForEach(locators, id: \.self) { locator in
                    SignerRow(
                        locator: locator,
                        canRemove: false,
                        onSelect: {}
                    )
                }
            }
        }
    }

    private func loadSigners() async {
        guard appState.wallet != nil else { return }
        isLoadingSigners = true
        await appState.loadSigners()
        isLoadingSigners = false
    }

    private func removeSigner(locator: String) async {
        guard let wallet = appState.wallet else { return }
        removingSignerLocator = locator
        do {
            _ = try await wallet.removeSigner(locator: locator)
            removingSignerLocator = nil
            await loadSigners()
            show(title: "Removed", message: "Signer removed.")
        } catch {
            show(title: "Error", message: error.userMessage)
            removingSignerLocator = nil
        }
    }

    private func show(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}
