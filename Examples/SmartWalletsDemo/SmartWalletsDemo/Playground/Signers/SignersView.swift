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

    private var isRemovingSigner: Bool { removingSignerLocator != nil }
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false

    var body: some View {
        NavigationStack {
            List {
                recoverySection()

                Section("Signers") {
                    if appState.delegatedSigners.isEmpty && !isLoadingSigners {
                        ContentUnavailableView(
                            "No Signers",
                            systemImage: "person.badge.key",
                            description: Text("No delegated signers are registered on this wallet.")
                        )
                    } else {
                        ForEach(appState.delegatedSigners, id: \.locator) { signer in
                            if let locator = signer.locator {
                                SignerRow(
                                    locator: locator,
                                    isRemoving: removingSignerLocator == locator,
                                    canRemove: true,
                                    onSelect: {},
                                    onRemove: { Task { await removeSigner(signer) } }
                                )
                            }
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
                }
            }
            .navigationTitle("Signers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .disabled(isRemovingSigner)
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
        .interactiveDismissDisabled(isRemovingSigner)
        .sheet(isPresented: $showAddSigner, onDismiss: { Task { await loadSigners() } }) {
            AddSignerSheet()
                .environment(appState)
        }
        .otpSheet()
    }

    @ViewBuilder
    private func recoverySection() -> some View {
        if let locator = appState.recoveryLocator {
            Section("Recovery") {
                SignerRow(
                    locator: locator,
                    canRemove: false,
                    onSelect: {}
                )
            }
        }
    }

    private func loadSigners() async {
        guard appState.wallet != nil else { return }
        isLoadingSigners = true
        await appState.loadSigners()
        isLoadingSigners = false
    }

    private func removeSigner(_ signer: WalletDelegatedSignerConfigApiModel) async {
        guard let wallet = appState.wallet, let locator = signer.locator else { return }
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
