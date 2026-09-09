//
//  RecoverySetupSection.swift
//  SmartWalletsDemo
//

import CrossmintClient
import SwiftUI

struct RecoverySetupSection: View {
    @Environment(AppState.self) private var appState
    let email: String
    let onCreated: () async -> Void

    @State private var drafts: [RecoverySignerDraft] = []

    private var canCreate: Bool {
        !appState.isCreatingWallet && drafts.allSatisfy(\.isComplete)
    }

    var body: some View {
        Section {
            SignerRow(locator: "email:\(email)", canRemove: false, onSelect: {})
            ForEach($drafts) { $draft in
                RecoverySignerDraftRow(
                    draft: $draft,
                    onRemove: { drafts.removeAll { $0.id == draft.id } }
                )
            }
            Button {
                drafts.append(RecoverySignerDraft())
            } label: {
                Label("Add Recovery Signer…", systemImage: "plus.circle")
            }
            .accessibilityIdentifier("recovery-add-button")
        } header: {
            Text("Recovery")
        } footer: {
            Text(
                "Each recovery signer can authorize on its own. "
                    + "The \(appState.selectedChain.chainDisplayName) wallet will be created with all of them."
            )
        }

        Section {
            Button {
                Task {
                    await appState.createWallet(email: email, extraRecovery: drafts)
                    if appState.wallet != nil {
                        await onCreated()
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    if appState.isCreatingWallet {
                        ProgressView().scaleEffect(0.8)
                    }
                    Text(appState.isCreatingWallet ? "Creating Wallet…" : "Create Wallet")
                        .fontWeight(.medium)
                }
            }
            .disabled(!canCreate)
            .accessibilityIdentifier("recovery-create-wallet-button")
            if let error = appState.walletErrorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .font(.footnote)
            }
        }
    }
}

private struct RecoverySignerDraftRow: View {
    @Binding var draft: RecoverySignerDraft
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Picker("Type", selection: $draft.kind) {
                    ForEach(RecoverySignerDraft.Kind.allCases) { kind in
                        Label(kind.rawValue, systemImage: kind.icon).tag(kind)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
                Spacer()
                Button("Remove", systemImage: "minus.circle", action: onRemove)
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.red)
                    .buttonStyle(.borderless)
            }
            if draft.kind.needsValue {
                TextField(draft.kind.rawValue, text: $draft.value, prompt: Text(draft.kind.placeholder))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(draft.kind == .phone ? .phonePad : .emailAddress)
                    .font(.system(.body, design: .monospaced))
                    .accessibilityIdentifier("recovery-value-field")
            }
            if draft.kind == .phone {
                Picker("OTP delivery", selection: $draft.channel) {
                    Text("SMS").tag(OTPDeliveryChannel.sms)
                    Text("WhatsApp").tag(OTPDeliveryChannel.whatsapp)
                }
                .pickerStyle(.segmented)
            }
        }
        .padding(.vertical, 4)
    }
}
