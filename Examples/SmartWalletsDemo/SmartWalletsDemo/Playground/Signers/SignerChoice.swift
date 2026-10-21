//
//  SignerChoice.swift
//  SmartWalletsDemo
//

import CrossmintClient

struct SignerChoice: Hashable, Identifiable {
    let locator: String
    let quorum: String?

    var id: String {
        guard let quorum else { return locator }
        return "\(quorum)/\(locator)"
    }

    var quorumLocator: SignerLocator? {
        quorum.flatMap { try? SignerLocator(from: $0) }
    }

    func belongs(to recoveryLocator: String) -> Bool {
        locator == recoveryLocator || quorum == recoveryLocator
    }
}
