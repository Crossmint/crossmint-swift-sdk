//
//  AddressRow.swift
//  SmartWalletsDemo
//

import SwiftUI

struct AddressRow: View {
    @Environment(AppState.self) private var appState
    @State private var addressCopied = false

    var body: some View {
        if let address = appState.wallet?.address {
            LabeledContent("Address") {
                Button {
                    UIPasteboard.general.string = address
                    addressCopied.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Text(formatAddress(address))
                            .foregroundStyle(.secondary)
                        Image(systemName: "doc.on.clipboard")
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                    }
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.success, trigger: addressCopied)
            }
        }
    }

    private func formatAddress(_ address: String) -> String {
        guard address.count > 10 else { return address }
        return "\(address.prefix(6))…\(address.suffix(4))"
    }
}
