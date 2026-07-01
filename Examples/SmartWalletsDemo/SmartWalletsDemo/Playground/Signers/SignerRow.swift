//
//  SignerRow.swift
//  SmartWalletsDemo
//

import SwiftUI

struct SignerRow: View {
    var index: Int? = nil
    let locator: String
    var isRemoving: Bool = false
    var canRemove: Bool = true
    let onSelect: () -> Void
    var onRemove: (() -> Void)?

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
        let prefix = locator.components(separatedBy: ":").first ?? ""
        let icon: String = switch prefix {
        case "device": "iphone"
        case "passkey": "touchid"
        case "email": "envelope"
        case "phone": "phone"
        case "api-key": "key"
        case "external-wallet": "wallet.bifold"
        case "server": "server.rack"
        default: "questionmark.circle"
        }
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
                    .accessibilityIdentifier(index.map { "signer-\($0)-locator" } ?? "")
            }
            Spacer()
            if isRemoving {
                ProgressView()
            }
        }
        .padding(.vertical, 2)
        .accessibilityIdentifier(index.map { "signer-\($0)" } ?? "")
        .swipeActions(edge: .trailing) {
            if canRemove, let onRemove {
                Button("Remove", role: .destructive, action: onRemove)
                    .disabled(isRemoving)
                    .accessibilityIdentifier(index.map { "signer-\($0)-remove" } ?? "")
            }
        }
    }
}
