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

    private var signers: [WalletDelegatedSignerConfigApiModel] {
        (appState.wallet?.signers ?? [])
            .filter { !removedLocators.contains($0.locator ?? "") }
    }

    var body: some View {
        NavigationStack {
            List {
                if signers.isEmpty && !appState.isLoadingWallet {
                    ContentUnavailableView(
                        "No Signers",
                        systemImage: "person.badge.key",
                        description: Text("No delegated signers are registered on this wallet.")
                    )
                } else {
                    Section("Registered Signers") {
                        ForEach(signers, id: \.locator) { signer in
                            SignerRow(
                                signer: signer,
                                isCurrentDevice: signer.locator == currentDeviceLocator,
                                isRemoving: removingSignerLocator == signer.locator,
                                onUse: { Task { await useSigner(signer) } },
                                onRemove: { Task { await removeSigner(signer) } }
                            )
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

    private func addDeviceSigner() async {
        guard let wallet = appState.wallet else { return }
        isAddingSigner = true
        do {
            try await wallet.addSigner(.device)
            await appState.reloadCurrentWallet()
            show(title: "Success", message: "Device signer added.")
        } catch {
            show(title: "Error", message: error.userMessage)
        }
        isAddingSigner = false
    }

    private func useSigner(_ signer: WalletDelegatedSignerConfigApiModel) async {
        guard let wallet = appState.wallet, let locator = signer.locator else { return }
        do {
            if locator.hasPrefix("device:") {
                try await wallet.useSigner(.device)
            } else if locator.hasPrefix("api-key:") {
                try await wallet.useSigner(.apiKey)
            }
            show(title: "Active Signer", message: "Now using \(locator)")
        } catch {
            show(title: "Error", message: error.userMessage)
        }
    }

    private func removeSigner(_ signer: WalletDelegatedSignerConfigApiModel) async {
        guard let wallet = appState.wallet, let locator = signer.locator else { return }
        removingSignerLocator = locator
        do {
            _ = try await wallet.removeSigner(locator: locator)
            removedLocators.insert(locator)
            await appState.reloadCurrentWallet()
            removedLocators.remove(locator)
            currentDeviceLocator = await appState.wallet?.currentDeviceSignerLocator()
            show(title: "Removed", message: "Signer removed.")
        } catch {
            show(title: "Error", message: error.userMessage)
        }
        removingSignerLocator = nil
    }

    private func show(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}
