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

    var body: some View {
        NavigationStack {
            List {
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
            .accessibilityIdentifier("signers-list")
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
