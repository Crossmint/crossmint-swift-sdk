//
//  RecoverySignerDraft.swift
//  SmartWalletsDemo
//

import CrossmintClient
import Foundation

struct RecoverySignerDraft: Identifiable, Equatable {
    enum Kind: String, CaseIterable, Identifiable {
        case email = "Email"
        case phone = "Phone"
        case apiKey = "API key"

        var id: Self { self }

        var needsValue: Bool { self != .apiKey }

        var icon: String {
            switch self {
            case .email: "envelope"
            case .phone: "phone"
            case .apiKey: "key"
            }
        }

        var placeholder: String {
            switch self {
            case .email: "user@example.com"
            case .phone: "+15551234567"
            case .apiKey: ""
            }
        }
    }

    let id = UUID()
    var kind: Kind = .phone
    var value = ""
    var channel: OTPDeliveryChannel = .sms

    var trimmedValue: String { value.trimmingCharacters(in: .whitespaces) }

    var isComplete: Bool { !kind.needsValue || !trimmedValue.isEmpty }

    var locator: String? {
        switch kind {
        case .email: "email:\(trimmedValue)"
        case .phone: "phone:\(trimmedValue)"
        case .apiKey: nil
        }
    }

    var solanaSigner: SolanaSigners {
        switch kind {
        case .email: .email(trimmedValue)
        case .phone: .phone(trimmedValue, channel: channel)
        case .apiKey: .apiKey
        }
    }

    var stellarSigner: StellarSigners {
        switch kind {
        case .email: .email(trimmedValue)
        case .phone: .phone(trimmedValue, channel: channel)
        case .apiKey: .apiKey
        }
    }
}
