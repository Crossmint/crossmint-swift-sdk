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
    @State private var showOTPView = false

    enum SignerTypeOption: String, CaseIterable, Identifiable {
        case device = "Device"
        case passkey = "Passkey"
        case externalWallet = "External Wallet"
        case server = "Server"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .device: return "iphone"
            case .passkey: return "touchid"
            case .externalWallet: return "wallet.bifold"
            case .server: return "server.rack"
            }
        }

        var needsInput: Bool {
            switch self {
            case .device, .passkey: return false
            default: return true
            }
        }

        var inputLabel: String {
            switch self {
            case .externalWallet: return "Wallet address"
            case .server: return "Server address"
            default: return ""
            }
        }

        var inputPlaceholder: String {
            switch self {
            case .externalWallet: return "0x..."
            case .server: return "0x..."
            default: return ""
            }
        }

        var description: String {
            switch self {
            case .device:
                return "Non-extractable P-256 key stored in the Secure Enclave (software keychain on simulator). Signs approvals on-device with no network call."
            case .passkey:
                return "WebAuthn credential registered via Face ID / Touch ID. EVM only. Requires passkeys entitlement and associated domain."
            case .externalWallet:
                return "Adds a pre-existing wallet address as a co-signer. Requires recovery-signer approval before it can be used."
            case .server:
                return "Server-managed signer whose private key is held by Crossmint. Registered immediately — useful for backend-controlled signing flows."
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
        guard !isAdding else { return false }
        if selectedType.needsInput { return !inputText.trimmingCharacters(in: .whitespaces).isEmpty }
        return appState.wallet != nil
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

                if selectedType.needsInput {
                    Section(selectedType.inputLabel) {
                        TextField(selectedType.inputPlaceholder, text: $inputText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.system(.body, design: .monospaced))
                    }
                }

                Section {
                    Text(selectedType.description)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
        .sheet(isPresented: $showOTPView) { OTPValidatorView() }
        .onReceive(CrossmintSDK.shared.isOTPRequired) { showOTPView = $0 }
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
                let host = Bundle.main.bundleIdentifier ?? "crossmint.demo"
                try await wallet.addSigner(.passkey(name: "Crossmint Demo", host: host))
            case .externalWallet:
                try await wallet.addSigner(.externalWallet(value))
            case .server:
                try await wallet.addSigner(.server(value))
            }
            dismiss()
        } catch {
            errorMessage = error.userMessage
        }

        isAdding = false
    }
}
