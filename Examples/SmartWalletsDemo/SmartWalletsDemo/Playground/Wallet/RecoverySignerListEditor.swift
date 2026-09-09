//
//  RecoverySignerListEditor.swift
//  SmartWalletsDemo
//

import CrossmintClient
import SwiftUI

struct RecoverySignerListEditor: View {
    let primaryLocator: String
    @Binding var drafts: [RecoverySignerDraft]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recovery signers")
                .font(.subheadline)
                .fontWeight(.medium)
            LabeledContent("1") {
                Text(primaryLocator)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            ForEach($drafts) { $draft in
                RecoverySignerDraftRow(
                    index: (drafts.firstIndex(of: draft) ?? 0) + 2,
                    draft: $draft,
                    onRemove: { drafts.removeAll { $0.id == draft.id } }
                )
            }
            Button("Add recovery signer", systemImage: "plus") {
                drafts.append(RecoverySignerDraft())
            }
            .font(.footnote)
            .accessibilityIdentifier("recovery-add-button")
        }
    }
}

private struct RecoverySignerDraftRow: View {
    let index: Int
    @Binding var draft: RecoverySignerDraft
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("\(index)")
                    .foregroundStyle(.secondary)
                Picker("Type", selection: $draft.kind) {
                    ForEach(RecoverySignerDraft.Kind.allCases) { kind in
                        Label(kind.rawValue, systemImage: kind.icon).tag(kind)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                if draft.kind.needsValue {
                    TextField(draft.kind.rawValue, text: $draft.value, prompt: Text(draft.kind.placeholder))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(draft.kind == .phone ? .phonePad : .emailAddress)
                        .font(.system(.footnote, design: .monospaced))
                        .accessibilityIdentifier("recovery-value-\(index)")
                }
                Spacer(minLength: 0)
                Button("Remove", systemImage: "minus.circle", action: onRemove)
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.red)
                    .buttonStyle(.borderless)
            }
            if draft.kind == .phone {
                Picker("OTP delivery", selection: $draft.channel) {
                    Text("SMS").tag(OTPDeliveryChannel.sms)
                    Text("WhatsApp").tag(OTPDeliveryChannel.whatsapp)
                }
                .pickerStyle(.segmented)
            }
        }
    }
}
