//
//  SignersView.swift
//  SmartWalletsDemo
//

import CrossmintClient
import SwiftUI

struct SignersView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var showAddSigner = false
    @State private var removingSignerLocator: String?
    @State private var selectingApproverLocator: String?
    @State private var isLoadingSigners = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false

    private var isRemovingSigner: Bool { removingSignerLocator != nil }

    let email: String?

    var body: some View {
        NavigationStack {
            List {
                if appState.wallet == nil, let email {
                    pendingRecoverySections(email: email)
                } else {
                    walletSections()
                }
            }
            .accessibilityIdentifier("signers-list")
            .navigationTitle("Signers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .disabled(isRemovingSigner || appState.isCreatingWallet)
                }
            }
            .alert(alertTitle, isPresented: $showAlert) {
            } message: {
                Text(alertMessage)
            }
            .task(id: appState.wallet?.address) {
                await loadSigners()
            }
        }
        .interactiveDismissDisabled(isRemovingSigner || appState.isCreatingWallet)
        .sheet(isPresented: $showAddSigner, onDismiss: { Task { await loadSigners() } }) {
            AddSignerSheet()
                .environment(appState)
        }
        .otpSheet()
    }

    @ViewBuilder
    private func pendingRecoverySections(email: String) -> some View {
        Section {
            SignerRow(locator: "email:\(email)", canRemove: false, onSelect: {})
            ForEach(appState.pendingRecovery) { draft in
                SignerRow(
                    locator: draft.locator,
                    canRemove: true,
                    onSelect: {},
                    onRemove: { appState.pendingRecovery.removeAll { $0.id == draft.id } }
                )
            }
        } header: {
            Text("Recovery")
        }

        if appState.selectedChain == .stellar {
            quorumDraftSection()
        }

        Section {
            Button {
                showAddSigner = true
            } label: {
                Label("Add Signer…", systemImage: "plus.circle")
            }
            .accessibilityIdentifier("signers-add-button")
        }

        Section {
            Button {
                Task { await appState.createWallet(email: email) }
            } label: {
                HStack(spacing: 8) {
                    if appState.isCreatingWallet {
                        ProgressView().scaleEffect(0.8)
                    }
                    Text(appState.isCreatingWallet ? "Creating Wallet…" : "Create Wallet")
                        .fontWeight(.medium)
                }
            }
            .disabled(appState.isCreatingWallet || quorumNeedsMoreMembers)
            .accessibilityIdentifier("recovery-create-wallet-button")
            if let error = appState.walletErrorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .font(.footnote)
            }
        }
    }

    private var quorumNeedsMoreMembers: Bool {
        appState.pendingQuorumThreshold != nil && appState.pendingRecovery.isEmpty
    }

    @ViewBuilder
    private func quorumDraftSection() -> some View {
        let memberCount = appState.pendingRecovery.count + 1
        Section {
            Toggle("Quorum", isOn: Binding(
                get: { appState.pendingQuorumThreshold != nil },
                set: { appState.pendingQuorumThreshold = $0 ? min(2, memberCount) : nil }
            ))
            .disabled(memberCount < 2 && appState.pendingQuorumThreshold == nil)
            .accessibilityIdentifier("recovery-quorum-toggle")
            if let threshold = appState.pendingQuorumThreshold.map({ min($0, memberCount) }) {
                Stepper(
                    "\(threshold) of \(memberCount) must approve",
                    value: Binding(
                        get: { threshold },
                        set: { appState.pendingQuorumThreshold = $0 }
                    ),
                    in: 1...memberCount
                )
                .accessibilityIdentifier("recovery-quorum-threshold")
            }
        }
    }

    @ViewBuilder
    private func walletSections() -> some View {
        recoverySection()

        Section("Signers") {
            if appState.signers.isEmpty && !isLoadingSigners {
                ContentUnavailableView(
                    "No Signers",
                    systemImage: "person.badge.key",
                    description: Text("No signers are registered on this wallet.")
                )
            } else {
                ForEach(Array(appState.signers.enumerated()), id: \.element.locator.value) { index, item in
                    SignerRow(
                        index: index,
                        locator: item.locator.value,
                        name: item.name,
                        status: item.status.rawValue,
                        isRemoving: removingSignerLocator == item.locator.value,
                        canRemove: true,
                        onSelect: {},
                        onRemove: { Task { await removeSigner(locator: item.locator) } }
                    )
                }
            }
        }

        Section {
            Button {
                showAddSigner = true
            } label: {
                Label("Add Signer…", systemImage: "plus.circle")
            }
            .disabled(appState.wallet == nil)
            .accessibilityIdentifier("signers-add-button")
        }
    }

    @ViewBuilder
    private func recoverySection() -> some View {
        let locators = appState.recoveryLocators
        let editable = appState.selectedChain.supportsRecoveryList
        if !locators.isEmpty {
            Section {
                ForEach(Array(locators.enumerated()), id: \.element) { index, locator in
                    recoveryRow(index: index, locator: locator, editable: editable)
                    if let quorum = appState.quorum(for: locator) {
                        ForEach(quorum.members.map(\.locator), id: \.self) { member in
                            quorumMemberRow(SignerChoice(locator: member, quorum: locator))
                        }
                    }
                }
            } header: {
                Text("Recovery")
            }
        }
    }

    private func quorumMemberRow(_ member: SignerChoice) -> some View {
        SignerRow(
            idPrefix: "quorum-member",
            locator: member.locator,
            status: appState.approvingRecoveryMethod == member ? "Approver" : "Member",
            isRemoving: selectingApproverLocator == member.id,
            canRemove: false,
            onSelect: {}
        )
        .padding(.leading, 24)
        .contentShape(Rectangle())
        .accessibilityAddTraits(.isButton)
        .onTapGesture {
            Task { await selectApprover(member) }
        }
    }

    private func recoveryRow(index: Int, locator: String, editable: Bool) -> some View {
        SignerRow(
            index: index,
            idPrefix: "recovery",
            locator: locator,
            name: appState.recoveryName(for: locator),
            status: appState.approvingRecoveryMethod?.id == locator ? "Approver" : nil,
            isRemoving: removingSignerLocator == locator || selectingApproverLocator == locator,
            canRemove: editable,
            onSelect: {},
            onRemove: { Task { await removeRecoveryMethod(locator: locator) } }
        )
        .contentShape(Rectangle())
        .accessibilityAddTraits(editable ? .isButton : [])
        .onTapGesture {
            guard editable, appState.quorum(for: locator) == nil else { return }
            Task { await selectApprover(SignerChoice(locator: locator, quorum: nil)) }
        }
    }

    private func loadSigners() async {
        guard appState.wallet != nil else { return }
        isLoadingSigners = true
        await appState.loadSigners()
        isLoadingSigners = false
    }

    private func removeSigner(locator: SignerLocator) async {
        guard let wallet = appState.wallet else { return }
        removingSignerLocator = locator.value
        do {
            _ = try await wallet.removeSigner(locator: locator)
            removingSignerLocator = nil
            await loadSigners()
            show(title: "Removed", message: "Signer removed.")
        } catch {
            show(title: "Error", message: error.userMessage)
            removingSignerLocator = nil
        }
    }

    private func removeRecoveryMethod(locator: String) async {
        removingSignerLocator = locator
        do {
            let transaction = try await appState.removeRecoveryMethod(locator: locator)
            if let transaction, transaction.status == .awaitingApproval {
                show(title: "Prepared for the quorum", message: transaction.id)
            } else {
                show(title: "Removed", message: "Recovery method removed.")
            }
        } catch {
            show(title: "Error", message: error.userMessage)
        }
        removingSignerLocator = nil
    }

    private func selectApprover(_ choice: SignerChoice) async {
        selectingApproverLocator = choice.id
        do {
            try await appState.useRecoveryMethod(choice)
        } catch {
            show(title: "Error", message: error.userMessage)
        }
        selectingApproverLocator = nil
    }

    private func show(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}
