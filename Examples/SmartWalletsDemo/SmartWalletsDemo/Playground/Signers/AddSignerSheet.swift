//
//  AddSignerSheet.swift
//  SmartWalletsDemo
//

import CrossmintClient
import SwiftUI

struct AddSignerSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedType: SignerTypeOption = .device
    @State private var inputText = ""
    @State private var channel: OTPDeliveryChannel = .sms
    @State private var isAdding = false
    @State private var errorMessage: String?

    enum SignerTypeOption: String, CaseIterable, Identifiable {
        case device = "Device"
        case passkey = "Passkey"
        case externalWallet = "External Wallet"
        case phone = "Phone"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .device: return "iphone"
            case .passkey: return "touchid"
            case .externalWallet: return "wallet.bifold"
            case .phone: return "phone"
            }
        }

        var showsInput: Bool {
            switch self {
            case .device: return false
            default: return true
            }
        }

        var inputRequired: Bool {
            switch self {
            case .externalWallet, .phone: return true
            default: return false
            }
        }

        var inputLabel: String {
            switch self {
            case .passkey: return "Name"
            case .externalWallet: return "Address"
            case .phone: return "Phone number"
            default: return ""
            }
        }

        var inputPlaceholder: String {
            switch self {
            case .passkey: return "e.g. My Yubikey"
            case .externalWallet: return "0x..."
            case .phone: return "+15551234567"
            default: return ""
            }
        }
    }

    private var availableTypes: [SignerTypeOption] {
        SignerTypeOption.allCases.filter { type in
            if appState.selectedChain != .evm && type == .passkey { return false }
            return true
        }
    }

    private var isValid: Bool {
        guard !isAdding, appState.wallet != nil else { return false }
        if selectedType.inputRequired { return !inputText.trimmingCharacters(in: .whitespaces).isEmpty }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Type") {
                    Picker("Signer Type", selection: $selectedType) {
                        ForEach(availableTypes) { type in
                            Label(type.rawValue, systemImage: type.icon).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }

                if selectedType.showsInput {
                    Section(selectedType.inputLabel) {
                        TextField(selectedType.inputPlaceholder, text: $inputText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(selectedType == .passkey ? .body : .system(.body, design: .monospaced))
                            .keyboardType(selectedType == .phone ? .phonePad : .default)
                    }
                }

                if selectedType == .phone {
                    Section("OTP delivery") {
                        Picker("Channel", selection: $channel) {
                            Text("SMS").tag(OTPDeliveryChannel.sms)
                            Text("WhatsApp").tag(OTPDeliveryChannel.whatsapp)
                        }
                        .pickerStyle(.segmented)
                    }
                }

                if let error = errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("Add Signer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .disabled(isAdding)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await addSigner() }
                    } label: {
                        if isAdding {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Text("Add").fontWeight(.semibold)
                        }
                    }
                    .disabled(!isValid)
                }
            }
            .onChange(of: selectedType) { _, _ in
                inputText = ""
                errorMessage = nil
            }
        }
        .interactiveDismissDisabled(isAdding)
        .otpSheet()
    }

    private var passkeyHost: String {
        Bundle.main.object(forInfoDictionaryKey: "PasskeyHost") as? String ?? ""
    }

    private func addSigner() async {
        guard let wallet = appState.wallet else { return }
        isAdding = true
        errorMessage = nil
        let value = inputText.trimmingCharacters(in: .whitespaces)

        do {
            switch selectedType {
            case .device:
                try await wallet.addSigner(.device)
            case .passkey:
                let passkeyName = value.isEmpty ? "Crossmint Demo" : value
                try await wallet.addSigner(.passkey(name: passkeyName, host: passkeyHost))
            case .externalWallet:
                try await wallet.addSigner(.externalWallet(value))
            case .phone:
                // The registration endpoint has no channel field, so the channel is remembered
                // here and supplied again when the signer is selected for signing.
                try await wallet.addSigner(.phone(value))
                appState.rememberChannel(channel, for: "phone:\(value)")
            }
            dismiss()
        } catch {
            errorMessage = error.userMessage
        }

        isAdding = false
    }
}
