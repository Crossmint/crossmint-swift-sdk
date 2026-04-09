//
//  SignerPickerSection.swift
//  SmartWalletsDemo
//

import CrossmintClient
import SwiftUI

private let defaultSignerTag = "default-signer"

/// A form section with a signer picker, shared across Transfer and Signing features.
struct SignerPickerSection: View {
    @Environment(AppState.self) private var appState
    @State private var errorMessage: String?

    private struct SignerOption: Identifiable {
        let id: String  // locator
        let label: String
        let icon: String

        var displayTitle: String {
            "\(label) (\(truncatedLocator))"
        }

        private var truncatedLocator: String {
            guard id.count > 6 else { return id }
            return "\(id.prefix(3))…\(id.suffix(3))"
        }
    }

    private var selectedTitle: String {
        guard let locator = appState.selectedSignerLocator, locator != defaultSignerTag else {
            return "Default"
        }
        let label = signerLabel(locator: locator)
        let truncated = locator.count > 6 ? "\(locator.prefix(3))…\(locator.suffix(3))" : locator
        return "\(label) (\(truncated))"
    }

    var body: some View {
        if let wallet = appState.wallet {
            let options = buildOptions(wallet: wallet)
            if !options.isEmpty {
                Section("Signer") {
                    Menu {
                        Button {
                            Task { await pick(locator: defaultSignerTag) }
                        } label: {
                            if appState.selectedSignerLocator == nil || appState.selectedSignerLocator == defaultSignerTag {
                                Label("Default", systemImage: "checkmark")
                            } else {
                                Text("Default")
                            }
                        }

                        Divider()

                        ForEach(options) { option in
                            Button {
                                Task { await pick(locator: option.id) }
                            } label: {
                                if appState.selectedSignerLocator == option.id {
                                    Label(option.displayTitle, systemImage: "checkmark")
                                } else {
                                    Label(option.displayTitle, systemImage: option.icon)
                                }
                            }
                        }
                    } label: {
                        LabeledContent("Active Signer", value: selectedTitle)
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
    }

    private func pick(locator: String) async {
        errorMessage = nil
        errorMessage = await appState.selectSigner(locator: locator)
    }

    private func buildOptions(wallet: Wallet) -> [SignerOption] {
        wallet.signers.compactMap { signer in
            guard let locator = signer.locator,
                  isSelectable(locator: locator) else { return nil }
            return SignerOption(
                id: locator,
                label: signerLabel(locator: locator),
                icon: signerIcon(locator: locator)
            )
        }
    }

    private func isSelectable(locator: String) -> Bool {
        locator.hasPrefix("device:") || locator.hasPrefix("email:") || locator.hasPrefix("api-key:")
    }

    private func signerLabel(locator: String) -> String {
        if locator.hasPrefix("device:") { return "Device" }
        if locator.hasPrefix("api-key:") { return "API Key" }
        if locator.hasPrefix("email:") { return String(locator.dropFirst("email:".count)) }
        return locator
    }

    private func signerIcon(locator: String) -> String {
        if locator.hasPrefix("device:") { return "iphone" }
        if locator.hasPrefix("api-key:") { return "key" }
        return "envelope"
    }
}
