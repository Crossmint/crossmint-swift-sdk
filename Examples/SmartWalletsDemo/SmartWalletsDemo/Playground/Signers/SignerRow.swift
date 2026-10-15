//
//  SignerRow.swift
//  SmartWalletsDemo
//

import SwiftUI

struct SignerRow: View {
    var index: Int?
    var idPrefix = "signer"
    let locator: String
    var name: String?
    var status: String?
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

    static func icon(for locator: String) -> String {
        let prefix = locator.components(separatedBy: ":").first ?? ""
        return switch prefix {
        case "device": "iphone"
        case "passkey": "touchid"
        case "email": "envelope"
        case "phone": "phone"
        case "api-key": "key"
        case "external-wallet": "wallet.bifold"
        case "server": "server.rack"
        default: "questionmark.circle"
        }
    }

    static func value(for locator: String) -> String {
        guard let separator = locator.firstIndex(of: ":") else { return locator }
        return String(locator[locator.index(after: separator)...])
    }

    static func shortValue(for locator: String) -> String {
        let value = value(for: locator)
        let keepsFullValue = locator.hasPrefix("email:") || locator.hasPrefix("phone:")
        guard !keepsFullValue, value.count > 18 else { return value }
        return "\(value.prefix(8))…\(value.suffix(7))"
    }

    static func title(for locator: String, name: String?) -> String {
        name ?? typeLabel(for: locator)
    }

    static func subtitle(for locator: String, name: String?) -> String {
        let value = shortValue(for: locator)
        guard name != nil else { return value }
        let type = typeLabel(for: locator)
        return value.isEmpty ? type : "\(type) · \(value)"
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Label(Self.title(for: locator, name: name), systemImage: Self.icon(for: locator))
                    .font(.headline)
                Text(Self.subtitle(for: locator, name: name))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .accessibilityLabel(locator)
                    .accessibilityIdentifier(index.map { "\(idPrefix)-\($0)-locator" } ?? "")
            }
            Spacer()
            if let status {
                Text(status)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
                    .accessibilityIdentifier(index.map { "\(idPrefix)-\($0)-status" } ?? "")
            }
            if isRemoving {
                ProgressView()
            }
        }
        .padding(.vertical, 2)
        .accessibilityIdentifier(index.map { "\(idPrefix)-\($0)" } ?? "")
        .swipeActions(edge: .trailing) {
            if canRemove, let onRemove {
                Button("Remove", role: .destructive, action: onRemove)
                    .disabled(isRemoving)
                    .accessibilityIdentifier(index.map { "\(idPrefix)-\($0)-remove" } ?? "")
            }
        }
    }
}
