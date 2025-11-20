import Foundation
import Auth

// Minimal auth abstraction for TEE usage without full AuthManager integration
public protocol TEEAuthProvider: Sendable {
    var jwt: String? { get async }
    var email: String? { get async }
}

extension AuthManager where Self: TEEAuthProvider {}
