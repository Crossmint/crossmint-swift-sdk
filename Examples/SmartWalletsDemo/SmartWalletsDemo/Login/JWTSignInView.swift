import CrossmintClient
import SwiftUI

struct JWTSignInView: View {
    @Binding var authenticationStatus: AuthenticationStatus?

    @State private var jwtToken = ""
    @State private var isSigningIn = false
    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            AuthHeaderView(
                title: "Bring your own auth",
                subtitle: "Specify your JWKS endpoint in the Crossmint admin panel, then paste a JWT for the user below."
            )

            Spacer()
                .frame(height: 40)

            TextEditor(text: $jwtToken)
                .font(.system(.caption, design: .monospaced))
                .frame(height: 100)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                        .shadow(
                            color: Color(.label).opacity(0.05),
                            radius: 2, x: 0, y: 1
                        )
                )
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .placeholder(when: jwtToken.isEmpty, alignment: .topLeading) {
                    Text("Paste JWT token…")
                        .foregroundStyle(Color(.placeholderText))
                        .font(.system(.caption, design: .monospaced))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }

            PrimaryButton(
                text: "Sign in",
                action: signIn,
                isLoading: isSigningIn,
                isDisabled: jwtToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )

            Spacer()

            CrossmintPoweredView()
                .padding(.bottom, 20)
        }
        .padding(.horizontal, 24)
        .background(Color(.systemBackground))
        .navigationBarTitleDisplayMode(.inline)
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Alert"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }

    private func signIn() {
        let token = jwtToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let email = emailFromJWT(token) else {
            alertMessage = "Invalid JWT: must contain an email claim."
            showAlert = true
            return
        }
        isSigningIn = true
        Task {
            await crossmintAuthManager.setJWT(token)
            let authStatus = AuthenticationStatus.authenticated(email: email, jwt: token, secret: "")
            withAnimation(AnimationConstants.easeInOut()) {
                authenticationStatus = authStatus
            }
            isSigningIn = false
        }
    }

    private func emailFromJWT(_ token: String) -> String? {
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return nil }

        var base64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder != 0 { base64 += String(repeating: "=", count: 4 - remainder) }

        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let email = json["email"] as? String else { return nil }
        return email
    }
}

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

#Preview {
    JWTSignInView(authenticationStatus: .constant(nil))
}
