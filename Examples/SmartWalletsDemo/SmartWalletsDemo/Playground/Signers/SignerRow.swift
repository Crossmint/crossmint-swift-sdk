//
//  SignerRow.swift
//  SmartWalletsDemo
//

import SwiftUI

struct SignerRow: View {
    let locator: String
    var isRemoving: Bool = false
    var isSelected: Bool = false
    var canSelect: Bool = true
    var canRemove: Bool = true
    let onSelect: () -> Void
    var onRemove: (() -> Void)? = nil

    private var signerInfo: (type: String, icon: String) {
        if locator.hasPrefix("device:") { return ("Device", "iphone") }
        if locator.hasPrefix("passkey:") { return ("Passkey", "touchid") }
        if locator.hasPrefix("email:") { return ("Email", "envelope") }
        if locator.hasPrefix("phone:") { return ("Phone", "phone") }
        if locator.hasPrefix("api-key:") { return ("API Key", "key") }
        if locator.hasPrefix("external-wallet:") { return ("External Wallet", "wallet.bifold") }
        if locator.hasPrefix("server:") { return ("Server", "server.rack") }
        return ("Unknown", "questionmark.circle")
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Label(signerInfo.type, systemImage: signerInfo.icon)
                    .font(.headline)
                Text(locator)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            if isRemoving {
                ProgressView()
            } else if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(.tint)
                    .fontWeight(.semibold)
            } else if canSelect {
                Button("Use") { onSelect() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.green)
            }
        }
        .padding(.vertical, 2)
        .swipeActions(edge: .trailing) {
            if canRemove, let onRemove {
                Button("Remove", role: .destructive, action: onRemove)
                    .disabled(isRemoving)
            }
        }
    }
}
