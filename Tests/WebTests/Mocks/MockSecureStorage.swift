//
//  MockSecureStorage.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 6/1/26.
//

import SecureStorage

final class MockSecureStorage: SecureStorage, @unchecked Sendable {
    private var oneTimeSecret: String?
    private var jwt: String?
    private var storedEmail: String?

    func getOneTimeSecret() async throws(SecureStorageError) -> String? { oneTimeSecret }
    func storeOneTimeSecret(_ secret: String) async throws(SecureStorageError) { oneTimeSecret = secret }
    func getJWT() async throws(SecureStorageError) -> String? { jwt }
    func storeJWT(_ secret: String) async throws(SecureStorageError) { jwt = secret }
    func getEmail() async throws(SecureStorageError) -> String? { storedEmail }
    func storeEmail(_ email: String) async throws(SecureStorageError) { storedEmail = email }
    func clear() { oneTimeSecret = nil; jwt = nil; storedEmail = nil }
}
