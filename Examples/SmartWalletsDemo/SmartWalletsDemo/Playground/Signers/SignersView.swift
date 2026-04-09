//
//  SignersView.swift
//  SmartWalletsDemo
//

import CrossmintClient
import SwiftUI

struct SignersView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var isAddingSigner = false
    @State private var removingSignerLocator: String?
    @State private var removedLocators: Set<String> = []
    @State private var currentDeviceLocator: String?

    private var isRemovingSigner: Bool { removingSignerLocator != nil }
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false
    @State private var showOTPView = false

    private var delegatedSigners: [WalletDelegatedSignerConfigApiModel] {
        (appState.wallet?.signers ?? [])
            .filter { !removedLocators.contains($0.locator ?? "") }
    }

    var body: some View {
        NavigationStack {
            List {
                if let wallet = appState.wallet {
                    recoverySection(wallet: wallet)
                }

                Section("Delegated Signers") {
                    if delegatedSigners.isEmpty && !appState.isLoadingWallet {
                        ContentUnavailableView(
                            "No Delegated Signers",
                            systemImage: "person.badge.key",
                            description: Text("No delegated signers are registered on this wallet.")
                        )
                    } else {
                        ForEach(delegatedSigners, id: \.locator) { signer in
                            if let locator = signer.locator {
                                SignerRow(
                                    locator: locator,
                                    isCurrentDevice: locator == currentDeviceLocator,
                                    isRemoving: removingSignerLocator == locator,
                                    isSelected: locator == appState.selectedSignerLocator,
                                    canRemove: true,
                                    onSelect: { Task { await selectSigner(locator: locator) } },
                                    onRemove: { Task { await removeSigner(signer) } }
                                )
                            }
                        }
                    }
                }

                Section("Add Signer") {
                    Button {
                        Task { await addDeviceSigner() }
                    } label: {
                        HStack(spacing: 8) {
                            if isAddingSigner {
                                ProgressView().scaleEffect(0.8)
                            }
                            Label(
                                isAddingSigner ? "Adding…" : "Add Device Signer",
                                systemImage: "iphone"
                            )
                        }
                    }
                    .disabled(isAddingSigner || appState.wallet == nil)
                }
            }
            .navigationTitle("Signers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .disabled(isAddingSigner || isRemovingSigner)
                }
            }
            .alert(alertTitle, isPresented: $showAlert) {
            } message: {
                Text(alertMessage)
            }
            .task {
                currentDeviceLocator = await appState.wallet?.currentDeviceSignerLocator()
            }
        }
        .interactiveDismissDisabled(isAddingSigner || isRemovingSigner)
        .sheet(isPresented: $showOTPView) { OTPValidatorView() }
        .onReceive(CrossmintSDK.shared.isOTPRequired) { showOTPView = $0 }
    }

    @ViewBuilder
    private func recoverySection(wallet: Wallet) -> some View {
        let locator = wallet.recoveryLocator
        let selectable = locator.hasPrefix("email:") || locator.hasPrefix("api-key:") || locator.hasPrefix("device:")
        Section("Recovery Signer") {
            SignerRow(
                locator: locator,
                isSelected: locator == appState.selectedSignerLocator,
                canSelect: selectable,
                canRemove: false,
                onSelect: { Task { await selectSigner(locator: locator) } }
            )
        }
    }

    private func selectSigner(locator: String) async {
        if let error = await appState.selectSigner(locator: locator) {
            show(title: "Error", message: error)
        }
    }

    private func addDeviceSigner() async {
        guard let wallet = appState.wallet else { return }
        isAddingSigner = true
        do {
            try await wallet.addSigner(.device)
            await refreshSigners()
            show(title: "Success", message: "Device signer added.")
        } catch {
            show(title: "Error", message: error.userMessage)
        }
        isAddingSigner = false
    }

    private func removeSigner(_ signer: WalletDelegatedSignerConfigApiModel) async {
        guard let wallet = appState.wallet, let locator = signer.locator else { return }
        removingSignerLocator = locator
        do {
            _ = try await wallet.removeSigner(locator: locator)
            removedLocators.insert(locator)
            removingSignerLocator = nil
            await refreshSigners()
            show(title: "Removed", message: "Signer removed.")
        } catch {
            show(title: "Error", message: error.userMessage)
            removingSignerLocator = nil
        }
    }

    private func refreshSigners() async {
        await appState.reloadCurrentWallet()
        currentDeviceLocator = await appState.wallet?.currentDeviceSignerLocator()
    }

    private func show(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}
