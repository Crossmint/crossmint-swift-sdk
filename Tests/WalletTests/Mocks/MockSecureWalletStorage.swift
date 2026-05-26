//
//  MockSecureWalletStorage.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 20/05/26.
//

import SecureStorage
@testable import Wallet

struct MockSecureWalletStorage: SecureWalletStorage {
    func savePrivateKey(_ privateKey: String, forEmail email: String) {}
    func getPrivateKey(forEmail email: String) -> String? { nil }
}
