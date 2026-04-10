//
//  SignerPicker.swift
//  SmartWalletsDemo
//

import SwiftUI

/// A form section with a "Sign with" picker.
/// Only renders when the wallet has more than one selectable signer.
struct SignerPicker: View {
    @Environment(AppState.self) private var appState
    private var selection: Binding<String> {
        Binding(
            get: { appState.selectedSignerLocator ?? options.first?.id ?? "" },
            set: { new in Task { await appState.selectSigner(locator: new) } }
        )
    }

    private struct Option: Identifiable {
        var id: String { locator }
        
        let locator: String
        let typeLabel: String
        let isRecovery: Bool
    }

    private var options: [Option] {
        var result: [Option] = []
        guard let wallet = appState.wallet else { return result }

        let recovery = wallet.recoveryLocator
        if isSelectable(recovery) {
            result.append(Option(locator: recovery, typeLabel: typeName(recovery), isRecovery: true))
        }
        for signer in wallet.signers {
            if let locator = signer.locator, isSelectable(locator) {
                result.append(Option(locator: locator, typeLabel: typeName(locator), isRecovery: false))
            }
        }
        return result
    }

    var body: some View {
        Section {
            Picker("Sign with", selection: selection) {
                ForEach(options) { opt in
                    Button { } label: {
                        Text(opt.typeLabel + (opt.isRecovery ? " (Recovery)" : ""))
                        Text(opt.id)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .tag(opt.id)
                }
            }
        }
    }

    private func isSelectable(_ locator: String) -> Bool {
        locator.hasPrefix("email:") || locator.hasPrefix("api-key:") || locator.hasPrefix("device:")
    }

    private func typeName(_ locator: String) -> String {
        if locator.hasPrefix("device:") { return "Device" }
        if locator.hasPrefix("passkey:") { return "Passkey" }
        if locator.hasPrefix("email:") { return "Email" }
        if locator.hasPrefix("phone:") { return "Phone" }
        if locator.hasPrefix("api-key:") { return "API Key" }
        if locator.hasPrefix("external-wallet:") { return "External Wallet" }
        if locator.hasPrefix("server:") { return "Server" }
        return "Unknown"
    }
}
