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
    @State private var isAdding = false
    @State private var errorMessage: String?

    enum SignerTypeOption: String, CaseIterable, Identifiable {
        case device = "Device"
        case passkey = "Passkey"
        case externalWallet = "External Wallet"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .device: return "iphone"
            case .passkey: return "touchid"
            case .externalWallet: return "wallet.bifold"
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
            case .externalWallet: return true
            default: return false
            }
        }

        var inputLabel: String {
            switch self {
            case .passkey: return "Name"
            case .externalWallet: return "Address"
            default: return ""
            }
        }

        var inputPlaceholder: String {
            switch self {
            case .passkey: return "e.g. My Yubikey"
            case .externalWallet: return "0x..."
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
        .otpSheet(flow: Bindable(appState).pendingOTPFlow)
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
            }
            dismiss()
        } catch {
            errorMessage = error.userMessage
        }

        isAdding = false
    }
}
