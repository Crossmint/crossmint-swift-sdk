//
//  CopyButton.swift
//  SmartWalletsDemo
//

import SwiftUI

struct CopyButton: View {
    let value: String
    var lineLimit: Int = 2
    @State private var copied = false

    var body: some View {
        Button {
            UIPasteboard.general.string = value
            copied.toggle()
        } label: {
            HStack(alignment: .top) {
                Text(value)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(lineLimit)
                Image(systemName: "doc.on.clipboard")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Copy")
        .sensoryFeedback(.success, trigger: copied)
    }
}
