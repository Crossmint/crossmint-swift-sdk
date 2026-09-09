//
//  NoWalletView.swift
//  SmartWalletsDemo
//

import CrossmintClient
import SwiftUI

struct NoWalletView: View {
    @Environment(AppState.self) private var appState
    let email: String?

    @State private var addRecoveryPhone = false
    @State private var recoveryPhone = ""
    @State private var channel: OTPDeliveryChannel = .sms

    private var trimmedPhone: String? {
        let phone = recoveryPhone.trimmingCharacters(in: .whitespaces)
        return addRecoveryPhone && !phone.isEmpty ? phone : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("No \(appState.selectedChain.chainDisplayName) wallet found.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if appState.selectedChain.supportsRecoveryList {
                recoveryPhoneFields
            }
            Button {
                Task {
                    if let email {
                        await appState.createWallet(email: email, recoveryPhone: trimmedPhone, channel: channel)
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
            .disabled(appState.isCreatingWallet || (addRecoveryPhone && trimmedPhone == nil))
        }
        .padding(.vertical, 4)
    }

    /// Lets the tester add a phone as a second recovery signer, next to the login email.
    @ViewBuilder
    private var recoveryPhoneFields: some View {
        Toggle("Add a phone recovery signer", isOn: $addRecoveryPhone)
            .font(.subheadline)
        if addRecoveryPhone {
            TextField("Recovery phone number", text: $recoveryPhone, prompt: Text("+15551234567"))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.phonePad)
                .font(.system(.body, design: .monospaced))
                .accessibilityIdentifier("recovery-phone-field")
            Picker("OTP delivery", selection: $channel) {
                Text("SMS").tag(OTPDeliveryChannel.sms)
                Text("WhatsApp").tag(OTPDeliveryChannel.whatsapp)
            }
            .pickerStyle(.segmented)
        }
    }
}
