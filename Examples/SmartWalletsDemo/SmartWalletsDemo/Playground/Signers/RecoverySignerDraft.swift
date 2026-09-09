//
//  RecoverySignerDraft.swift
//  SmartWalletsDemo
//

import Foundation

struct RecoverySignerDraft: Identifiable, Equatable {
    enum Kind: Equatable {
        case email(String)
        case phone(String)
        case apiKey
    }

    let id = UUID()
    let kind: Kind

    var locator: String {
        switch kind {
        case .email(let email): "email:\(email)"
        case .phone(let phone): "phone:\(phone)"
        case .apiKey: "api-key"
        }
    }
}
