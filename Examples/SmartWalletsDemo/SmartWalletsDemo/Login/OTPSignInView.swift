import CrossmintClient
import SwiftUI

struct OTPSignInView: View {
    @Binding var authenticationStatus: AuthenticationStatus?

    @State private var email = ""
    @State private var isSigningIn = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showOTPVerification = false
    @State private var verifiedAuthStatus: AuthenticationStatus?
    @State private var requestId: String?

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

            PrimaryButton(
                text: "Sign in",
                action: signIn,
                isLoading: isSigningIn,
                isDisabled: email.isEmpty
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
        .sheet(isPresented: $showOTPVerification) {
            if let requestId {
                VerificationView(
                    authenticationStatus: $verifiedAuthStatus,
                    email: email,
                    requestId: requestId
                )
                .presentationDetents([.medium])
            }
        }
        .onChange(of: verifiedAuthStatus) { _, value in
            guard let value else { return }
            showOTPVerification = false
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
                requestId = otpRequest.requestId
                isSigningIn = false
                showOTPVerification = true
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
