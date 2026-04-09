//
//  SignerPickerSection.swift
//  SmartWalletsDemo
//

import CrossmintClient
import SwiftUI

/// A form section with a signer picker, shared across Transfer and Signing features.
struct SignerPickerSection: View {
    @Environment(AppState.self) private var appState
    @State private var errorMessage: String?

    private struct SignerOption: Identifiable {
        let id: String  // locator
        let label: String
        let icon: String
    }

    var body: some View {
        if let wallet = appState.wallet {
            let options = buildOptions(wallet: wallet)
            if options.count > 1 {
                Section("Signer") {
                    Picker("Active Signer", selection: Binding<String>(
                        get: { appState.selectedSignerLocator ?? wallet.config.recovery.locator },
                        set: { locator in Task { await pick(locator: locator, wallet: wallet) } }
                    )) {
                        ForEach(options) { option in
                            Label(option.label, systemImage: option.icon).tag(option.id)
                        }
                    }
                    .pickerStyle(.menu)

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
    }

    private func pick(locator: String, wallet: Wallet) async {
        errorMessage = nil
        errorMessage = await appState.selectSigner(locator: locator)
    }

    private func buildOptions(wallet: Wallet) -> [SignerOption] {
        var options: [SignerOption] = []

        // Recovery signer (always first)
        let recovery = wallet.config.recovery
        options.append(SignerOption(
            id: recovery.locator,
            label: signerLabel(locator: recovery.locator) + " (Recovery)",
            icon: signerIcon(locator: recovery.locator)
        ))

        // Delegated signers that the app can select
        for signer in wallet.signers {
            guard let locator = signer.locator,
                  isSelectable(locator: locator) else { continue }
            options.append(SignerOption(
                id: locator,
                label: signerLabel(locator: locator),
                icon: signerIcon(locator: locator)
            ))
        }

        return options
    }

    private func isSelectable(locator: String) -> Bool {
        locator.hasPrefix("device:") || locator.hasPrefix("email:") || locator.hasPrefix("api-key:")
    }

    private func signerLabel(locator: String) -> String {
        if locator.hasPrefix("device:") { return "Device" }
        if locator.hasPrefix("passkey:") { return "Passkey" }
        if locator.hasPrefix("api-key:") { return "API Key" }
        if locator.hasPrefix("external-wallet:") { return "External Wallet" }
        if locator.hasPrefix("email:") { return String(locator.dropFirst("email:".count)) }
        return locator
    }

    private func signerIcon(locator: String) -> String {
        if locator.hasPrefix("device:") { return "iphone" }
        if locator.hasPrefix("passkey:") { return "touchid" }
        if locator.hasPrefix("api-key:") { return "key" }
        if locator.hasPrefix("external-wallet:") { return "wallet.bifold" }
        return "envelope"
    }
}
