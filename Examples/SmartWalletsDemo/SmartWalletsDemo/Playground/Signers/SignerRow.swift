//
//  SignerRow.swift
//  SmartWalletsDemo
//

import CrossmintClient
import SwiftUI

struct SignerRow: View {
    let signer: WalletDelegatedSignerConfigApiModel
    var isCurrentDevice: Bool = false
    var isRemoving: Bool = false
    let onUse: () -> Void
    let onRemove: () -> Void

    private var signerType: String {
        guard let locator = signer.locator else { return "Unknown" }
        if locator.hasPrefix("device:") { return "Device" }
        if locator.hasPrefix("passkey:") { return "Passkey" }
        if locator.hasPrefix("email:") { return "Email" }
        if locator.hasPrefix("api-key:") { return "API Key" }
        if locator.hasPrefix("external-wallet:") { return "External Wallet" }
        return "Unknown"
    }

    private var signerSystemImage: String {
        guard let locator = signer.locator else { return "questionmark.circle" }
        if locator.hasPrefix("device:") { return "iphone" }
        if locator.hasPrefix("passkey:") { return "touchid" }
        if locator.hasPrefix("email:") { return "envelope" }
        if locator.hasPrefix("api-key:") { return "key" }
        if locator.hasPrefix("external-wallet:") { return "wallet.bifold" }
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
                if let locator = signer.locator {
                    Text(locator)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer()
            if isRemoving {
                ProgressView()
            }
        }
        .padding(.vertical, 2)
        .swipeActions(edge: .trailing) {
            Button("Remove", role: .destructive, action: onRemove)
                .disabled(isRemoving)
        }
        .swipeActions(edge: .leading) {
            Button("Use", action: onUse)
                .tint(.green)
                .disabled(isRemoving)
        }
    }
}
