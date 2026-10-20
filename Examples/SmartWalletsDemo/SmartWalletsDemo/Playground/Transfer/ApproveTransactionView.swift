//
//  ApproveTransactionView.swift
//  SmartWalletsDemo
//

import CrossmintClient
import SwiftUI

struct ApproveTransactionView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var transactionId = ""
    @State private var isApproving = false
    @State private var result: WalletTransaction?
    @State private var errorMessage: String?

    private var trimmedId: String {
        transactionId.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Transaction ID") {
                    TextField("Transaction ID", text: $transactionId)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                        .accessibilityIdentifier("approve-transaction-id-input")
                }

                Section {
                    SignerPicker()
                }

                if let result {
                    Section("Result") {
                        LabeledContent("Status", value: result.status.rawValue)
                            .accessibilityIdentifier("approve-status-label")
                        QuorumProgressRows(transaction: result)
                    }
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                            .font(.footnote)
                            .accessibilityIdentifier("approve-error-label")
                    }
                }

                Section {
                    Button {
                        Task { await approve() }
                    } label: {
                        HStack {
                            Spacer()
                            if isApproving { ProgressView().padding(.trailing, 8) }
                            Text(isApproving ? "Approving…" : "Approve")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(trimmedId.isEmpty || isApproving)
                    .accessibilityIdentifier("approve-submit-button")
                }
            }
            .navigationTitle("Approve")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .disabled(isApproving)
                }
            }
        }
        .interactiveDismissDisabled(isApproving)
        .otpSheet()
    }

    private func approve() async {
        isApproving = true
        errorMessage = nil
        result = nil
        do {
            result = try await appState.approve(transactionId: trimmedId)
            await appState.fetchBalance()
        } catch {
            errorMessage = error.userMessage
        }
        isApproving = false
    }
}

struct QuorumProgressRows: View {
    let transaction: WalletTransaction

    var body: some View {
        ForEach(transaction.approvals?.quorums ?? [], id: \.signer.value) { quorum in
            LabeledContent(
                "Quorum",
                value: "\(quorum.threshold - quorum.remaining) of \(quorum.threshold) approved"
            )
            .accessibilityIdentifier("quorum-progress-label")
            ForEach(quorum.remaining > 0 ? quorum.pendingMembers : [], id: \.value) { member in
                Label(SignerRow.shortValue(for: member.value), systemImage: "clock")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    ApproveTransactionView()
        .environment(AppState())
}
