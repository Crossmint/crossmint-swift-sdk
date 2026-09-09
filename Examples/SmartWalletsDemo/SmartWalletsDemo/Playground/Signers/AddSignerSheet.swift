//
//  AddSignerSheet.swift
//  SmartWalletsDemo
//

import CrossmintClient
import SwiftUI

struct AddSignerSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var mode: Mode = .signer
    @State private var selectedType: SignerTypeOption = .device
    @State private var inputText = ""
    @State private var channel: OTPDeliveryChannel = .sms
    @State private var isAdding = false
    @State private var errorMessage: String?

    enum Mode: String, CaseIterable, Identifiable {
        case recovery = "Recovery"
        case signer = "Signer"

        var id: String { rawValue }
    }

    enum SignerTypeOption: String, CaseIterable, Identifiable {
        case device = "Device"
        case passkey = "Passkey"
        case externalWallet = "External Wallet"
        case email = "Email"
        case phone = "Phone"
        case apiKey = "API Key"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .device: return "iphone"
            case .passkey: return "touchid"
            case .externalWallet: return "wallet.bifold"
            case .email: return "envelope"
            case .phone: return "phone"
            case .apiKey: return "key"
            }
        }

        var showsInput: Bool {
            switch self {
            case .device, .apiKey: return false
            default: return true
            }
        }

        var inputRequired: Bool {
            switch self {
            case .externalWallet, .email, .phone: return true
            default: return false
            }
        }

        var inputLabel: String {
            switch self {
            case .passkey: return "Name"
            case .externalWallet: return "Address"
            case .email: return "Email"
            case .phone: return "Phone number"
            default: return ""
            }
        }

        var inputPlaceholder: String {
            switch self {
            case .passkey: return "e.g. My Yubikey"
            case .externalWallet: return "0x..."
            case .email: return "user@example.com"
            case .phone: return "+15551234567"
            default: return ""
            }
        }

        var keyboard: UIKeyboardType {
            switch self {
            case .email: return .emailAddress
            case .phone: return .phonePad
            default: return .default
            }
        }
    }

    private var canAddRecovery: Bool {
        appState.wallet == nil && appState.selectedChain.supportsRecoveryList
    }

    private var canAddSigner: Bool {
        appState.wallet != nil
    }

    private var availableTypes: [SignerTypeOption] {
        switch mode {
        case .recovery:
            return [.email, .phone, .apiKey]
        case .signer:
            return [.device, .passkey, .externalWallet, .phone].filter { type in
                if appState.selectedChain != .evm && type == .passkey { return false }
                return true
            }
        }
    }

    private var modeUnavailableMessage: String? {
        switch mode {
        case .recovery where !canAddRecovery:
            return appState.wallet == nil
                ? "\(appState.selectedChain.chainDisplayName) wallets take a single recovery signer."
                : "Recovery signers are fixed when the wallet is created."
        case .signer where !canAddSigner:
            return "Create the wallet before adding signers."
        default:
            return nil
        }
    }

    private var isValid: Bool {
        guard !isAdding, modeUnavailableMessage == nil else { return false }
        if selectedType.inputRequired { return !inputText.trimmingCharacters(in: .whitespaces).isEmpty }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Add as", selection: $mode) {
                        ForEach(Mode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("add-signer-mode")
                } footer: {
                    if let modeUnavailableMessage {
                        Text(modeUnavailableMessage)
                    }
                }

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
                            .keyboardType(selectedType.keyboard)
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
                        Task { await add() }
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
            .onAppear {
                mode = canAddSigner ? .signer : .recovery
                selectedType = availableTypes[0]
            }
            .onChange(of: mode) { _, _ in
                selectedType = availableTypes[0]
                inputText = ""
                errorMessage = nil
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

    private func add() async {
        switch mode {
        case .recovery:
            addRecoveryDraft()
        case .signer:
            await addSigner()
        }
    }

    private func addRecoveryDraft() {
        let value = inputText.trimmingCharacters(in: .whitespaces)
        let kind: RecoverySignerDraft.Kind
        switch selectedType {
        case .email: kind = .email(value)
        case .phone: kind = .phone(value)
        case .apiKey: kind = .apiKey
        default: return
        }
        let draft = RecoverySignerDraft(kind: kind)
        if selectedType == .phone {
            appState.rememberChannel(channel, for: draft.locator)
        }
        appState.pendingRecovery.append(draft)
        dismiss()
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
            case .email, .apiKey:
                return
            }
            dismiss()
        } catch {
            errorMessage = error.userMessage
        }

        isAdding = false
    }
}
