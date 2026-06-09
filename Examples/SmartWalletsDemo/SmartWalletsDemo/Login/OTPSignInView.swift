import CrossmintClient
import SwiftUI

struct OTPSignInView: View {
    @Binding var authenticationStatus: AuthenticationStatus?

    @State private var email = ""
    @State private var isSigningIn = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var verifiedAuthStatus: AuthenticationStatus?
    @State private var pendingOTPRequest: OTPRequest?

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            AuthHeaderView(
                title: "Sign in with Crossmint",
                subtitle: "Enter your email to receive a verification code"
            )

            Spacer()
                .frame(height: 40)

            CustomTextField(
                placeholder: "email@example.com",
                text: $email,
                keyboardType: .emailAddress
            )
            .autocapitalization(.none)
            .disableAutocorrection(true)
            .textContentType(.emailAddress)
            .accessibilityIdentifier("email-input")

            PrimaryButton(
                text: "Sign in",
                action: signIn,
                isLoading: isSigningIn,
                isDisabled: email.isEmpty
            )
            .accessibilityIdentifier("send-code-button")

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
        .sheet(item: $pendingOTPRequest) { request in
            VerificationView(
                authenticationStatus: $verifiedAuthStatus,
                email: email,
                requestId: request.requestId
            )
            .presentationDetents([.medium])
        }
        .onChange(of: verifiedAuthStatus) { _, value in
            guard let value else { return }
            pendingOTPRequest = nil
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(AnimationConstants.duration))
                withAnimation(AnimationConstants.easeInOut()) {
                    authenticationStatus = value
                }
            }
        }
    }

    private func signIn() {
        guard !email.isEmpty else { return }
        isSigningIn = true
        Task {
            do {
                let otpRequest = try await CrossmintSDK.shared.authClient.sendOTP(to: email)
                isSigningIn = false
                pendingOTPRequest = otpRequest
            } catch let authError as AuthError {
                isSigningIn = false
                alertMessage = authError.errorMessage
                showAlert = true
            }
        }
    }
}

#Preview {
    OTPSignInView(authenticationStatus: .constant(nil))
}
