import CrossmintAuth
import Foundation

package actor StubAuthManager: AuthManager {
    private var _jwt: String?

    package init() {}

    package var jwt: String? {
        get async { _jwt }
    }

    package func setJWT(_ jwt: String) async {
        _jwt = jwt
    }
}
