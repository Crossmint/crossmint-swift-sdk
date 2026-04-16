//
//  TransferView.swift
//  SmartWalletsDemo
//

import CrossmintClient
import SwiftUI

struct TransferView: View {
    var onComplete: (() async -> Void)?

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var recipientAddress = ""
    @State private var amount = ""
    @State private var selectedTokenIndex = 0
    @State private var isSending = false
    @State private var transactionId: String?
    @State private var errorMessage: String?
    @State private var txCopied = false

    private var tokens: [(name: String, locator: String)] {
        appState.selectedChain.transferTokens
    }

    private var selectedTokenBalance: String? {
        guard let balance = appState.balance else { return nil }
        let tokenName = tokens[selectedTokenIndex].name.lowercased()
        let all = [balance.nativeToken, balance.usdc] + balance.tokens
        return all.first { $0.name.lowercased() == tokenName || $0.symbol.value.lowercased() == tokenName }.map { tb in
            let value = Double(tb.amount) ?? 0
            let fractionLength = value < 0.001 ? 6 : (value < 1 ? 4 : 2)
            return "\(value.formatted(.number.precision(.fractionLength(fractionLength)))) \(tb.symbol.value.uppercased())"
        }
    }

    private var isFormValid: Bool {
        !recipientAddress.trimmingCharacters(in: .whitespaces).isEmpty
            && Double(amount) != nil
            && appState.wallet != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Token") {
                    Picker("Token", selection: $selectedTokenIndex) {
                        ForEach(tokens.indices, id: \.self) { i in
                            Text(tokens[i].name).tag(i)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                Section("Recipient") {
                    TextField("Address", text: $recipientAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                }

                Section("Amount") {
                    TextField("0.00", text: $amount)
                        .keyboardType(.decimalPad)
                    if let bal = selectedTokenBalance {
                        LabeledContent("Balance", value: bal)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                SignerPicker()

                if let txId = transactionId {
                    Section("Sent") {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Transaction submitted", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .fontWeight(.medium)
                            CopyButton(value: txId, lineLimit: 2)
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
                        Task { await send() }
                    } label: {
                        HStack {
                            Spacer()
                            if isSending { ProgressView().padding(.trailing, 8) }
                            Text(isSending ? "Sending…" : "Send")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(!isFormValid || isSending)
                }
            }
            .navigationTitle("Transfer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .disabled(isSending)
                }
            }
        }
        .interactiveDismissDisabled(isSending)
        .otpSheet()
    }

    private func send() async {
        guard let wallet = appState.wallet, let amountValue = Double(amount) else { return }
        isSending = true
        errorMessage = nil
        transactionId = nil
        let locator = tokens[selectedTokenIndex].locator
        do {
            let result = try await wallet.send(recipientAddress.trimmingCharacters(in: .whitespaces), locator, amountValue)
            transactionId = result.hash
            recipientAddress = ""
            amount = ""
            await onComplete?()
        } catch {
            errorMessage = error.userMessage
        }
        isSending = false
    }
}

#Preview {
    TransferView()
        .environment(AppState())
}
