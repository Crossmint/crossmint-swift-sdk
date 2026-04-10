//
//  SignerRow.swift
//  SmartWalletsDemo
//

import SwiftUI

struct SignerRow: View {
    let locator: String
    var isCurrentDevice: Bool = false
    var isRemoving: Bool = false
    var isSelected: Bool = false
    var canSelect: Bool = true
    var canRemove: Bool = true
    let onSelect: () -> Void
    var onRemove: (() -> Void)? = nil

    private var signerType: String {
        if locator.hasPrefix("device:") { return "Device" }
        if locator.hasPrefix("passkey:") { return "Passkey" }
        if locator.hasPrefix("email:") { return "Email" }
        if locator.hasPrefix("phone:") { return "Phone" }
        if locator.hasPrefix("api-key:") { return "API Key" }
        if locator.hasPrefix("external-wallet:") { return "External Wallet" }
        if locator.hasPrefix("server:") { return "Server" }
        return "Unknown"
    }

    private var signerSystemImage: String {
        if locator.hasPrefix("device:") { return "iphone" }
        if locator.hasPrefix("passkey:") { return "touchid" }
        if locator.hasPrefix("email:") { return "envelope" }
        if locator.hasPrefix("phone:") { return "phone" }
        if locator.hasPrefix("api-key:") { return "key" }
        if locator.hasPrefix("external-wallet:") { return "wallet.bifold" }
        if locator.hasPrefix("server:") { return "server.rack" }
        return "questionmark.circle"
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Label(signerType, systemImage: signerSystemImage)
                        .font(.headline)
                    if isCurrentDevice {
                        Text("This device")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.green, in: Capsule())
                    }
                }
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
