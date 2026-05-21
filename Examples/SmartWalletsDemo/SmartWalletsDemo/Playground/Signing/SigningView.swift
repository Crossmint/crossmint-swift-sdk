//
//  SigningView.swift
//  SmartWalletsDemo
//

import CrossmintClient
import SwiftUI

struct SigningView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    private var wallet: EVMWallet? { appState.wallet as? EVMWallet }
    @State private var mode: SigningMode = .message
    @State private var messageText = ""
    @State private var signature: String?
    @State private var isSigning = false
    @State private var errorMessage: String?
    @FocusState private var isMessageFocused: Bool

    enum SigningMode: String, CaseIterable {
        case message = "Message"
        case typedData = "Typed Data"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Mode", selection: $mode) {
                        ForEach(SigningMode.allCases, id: \.self) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                if mode == .message {
                    Section("Message") {
                        TextField("Enter message to sign…", text: $messageText, axis: .vertical)
                            .lineLimit(4...)
                            .focused($isMessageFocused)
                    }
                } else {
                    Section("Typed Data") {
                        Text("Uses hardcoded EIP-712 example (Ether Mail).")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                SignerPicker()

                if let sig = signature {
                    Section("Signature") {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Signed successfully", systemImage: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                                .fontWeight(.medium)
                            CopyButton(value: sig, lineLimit: 4)
                        }
                    }
                }

                if let error = errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }

                Section {
                    Button {
                        Task { await sign() }
                    } label: {
                        HStack {
                            Spacer()
                            if isSigning { ProgressView().padding(.trailing, 8) }
                            Text(isSigning ? "Signing…" : "Sign")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(isSigning || wallet == nil || (mode == .message && messageText.isEmpty))
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Signing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .disabled(isSigning)
                }
            }
        }
        .interactiveDismissDisabled(isSigning)
        .otpSheet(flow: Bindable(appState).pendingOTPFlow)
    }

    private func sign() async {
        guard let wallet else { return }
        isMessageFocused = false
        isSigning = true
        signature = nil
        errorMessage = nil
        do {
            switch mode {
            case .message:
                signature = try await wallet.signMessage(messageText)
            case .typedData:
                signature = try await wallet.signTypedData(try exampleTypedData())
            }
        } catch {
            errorMessage = error.userMessage
        }
        isSigning = false
    }

    private func exampleTypedData() throws -> EIP712.TypedData {
        let built = EIP712.Builder()
            .withDomain(EIP712.Domain(
                name: "Ether Mail",
                version: "1",
                chainId: 1,
                verifyingContract: "0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC"
            ))
            .defineType("Person") { $0.string("name").address("wallet") }
            .defineType("Mail") { $0.field("from", type: "Person").field("to", type: "Person").string("contents") }
            .withPrimaryType("Mail")
            .withMessage([
                "from": ["name": "Cow", "wallet": "0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826"],
                "to": ["name": "Bob", "wallet": "0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB"],
                "contents": "Hello, Bob!"
            ])
            .build()
        guard let typedData = built else { throw SignatureError.creationFailed }
        return typedData
    }
}

#Preview {
    SigningView()
        .environment(AppState())
}
