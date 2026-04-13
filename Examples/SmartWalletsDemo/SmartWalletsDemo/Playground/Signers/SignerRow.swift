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

    static func typeLabel(for locator: String) -> String {
        if locator.hasPrefix("device:") { return "Device" }
        if locator.hasPrefix("passkey:") { return "Passkey" }
        if locator.hasPrefix("email:") { return "Email" }
        if locator.hasPrefix("phone:") { return "Phone" }
        if locator.hasPrefix("api-key:") { return "API Key" }
        if locator.hasPrefix("external-wallet:") { return "External Wallet" }
        if locator.hasPrefix("server:") { return "Server" }
        return "Unknown"
    }

    private var signerInfo: (type: String, icon: String) {
        let type = Self.typeLabel(for: locator)
        let icon: String
        if locator.hasPrefix("device:") { icon = "iphone" }
        else if locator.hasPrefix("passkey:") { icon = "touchid" }
        else if locator.hasPrefix("email:") { icon = "envelope" }
        else if locator.hasPrefix("phone:") { icon = "phone" }
        else if locator.hasPrefix("api-key:") { icon = "key" }
        else if locator.hasPrefix("external-wallet:") { icon = "wallet.bifold" }
        else if locator.hasPrefix("server:") { icon = "server.rack" }
        else { icon = "questionmark.circle" }
        return (type, icon)
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
