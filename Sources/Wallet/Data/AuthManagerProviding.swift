import CrossmintAuth
import CrossmintService

protocol AuthManagerProviding: AuthenticatedService {
    var authManager: AuthManager { get }
}

extension AuthManagerProviding {
    var authHeaders: [String: String] {
        get async {
            guard let jwt = await authManager.jwt else { return [:] }
            return ["Authorization": "Bearer \(jwt)"]
        }
    }
}
