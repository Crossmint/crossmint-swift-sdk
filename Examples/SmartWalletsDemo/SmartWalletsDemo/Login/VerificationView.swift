import SwiftUI
import CrossmintClient

struct VerificationView: View {
    @Binding var authenticationStatus: AuthenticationStatus?

    @State private var verificationCode: String = ""
    @State private var isVerifying: Bool = false
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var opacity: Double = 0
    @State private var currentRequestId: String

    let email: String

    init(authenticationStatus: Binding<AuthenticationStatus?>, email: String, requestId: String) {
        self._authenticationStatus = authenticationStatus
        self.email = email
        self._currentRequestId = State(initialValue: requestId)
    }

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("OTP Verification")
                    .font(.title3)
                    .fontWeight(.bold)

                Spacer()

                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
            }
            .padding(.top, 20)

            CustomTextField(
                placeholder: "Verification code",
                text: $verificationCode,
                keyboardType: .numberPad,
                multilineTextAlignment: .center
            )
            .autocapitalization(.none)
            .disableAutocorrection(true)

            PrimaryButton(
                text: "Verify",
                action: verifyCode,
                isLoading: isVerifying,
                isDisabled: verificationCode.isEmpty
            )

            SecondaryButton(
                text: "Resend code",
                icon: "arrow.2.circlepath",
                action: resendCode
            )
            .padding(.top, 5)

            Spacer()
        }
        .padding(.horizontal, 24)
        .background(Color(.systemBackground))
        .opacity(opacity)
        .onAppear {
            withAnimation(AnimationConstants.easeIn()) {
                opacity = 1
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Alert"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }

    private func verifyCode() {
        guard !verificationCode.isEmpty else { return }
        isVerifying = true
        Task {
            do {
                let authStatus = try await resolveSession(for: verificationCode)
                await animateSuccess(authStatus: authStatus)
            } catch {
                isVerifying = false
                showAlert(with: "Error: \(error.localizedDescription)")
                print("Error verifying code: \(error)")
            }
        }
    }

    private func resolveSession(for code: String) async throws -> AuthenticationStatus {
        let session = try await CrossmintSDK.shared.authClient.verifyOTP(code: code, requestId: currentRequestId)
        // secret is intentionally empty — refresh state lives in CrossmintAuthManager, not this binding
        return .authenticated(email: session.user.email, jwt: session.jwt, secret: "")
    }

    private func animateSuccess(authStatus: AuthenticationStatus) async {
        isVerifying = false
        withAnimation(AnimationConstants.easeOut()) { opacity = 0 }
        try? await Task.sleep(for: .seconds(AnimationConstants.duration))
        authenticationStatus = authStatus
    }

    private func resendCode() {
        Task {
            do {
                let otpRequest = try await CrossmintSDK.shared.authClient.sendOTP(to: email)
                currentRequestId = otpRequest.requestId
                showAlert(with: "A new verification code has been sent to your email.")
            } catch {
                showAlert(with: "Error sending new code: \(error.localizedDescription)")
                print("Error resending code: \(error)")
            }
        }
    }

    private func dismiss() {
        withAnimation(AnimationConstants.easeOut()) {
            opacity = 0
        }

        Task {
            try? await Task.sleep(for: .seconds(AnimationConstants.duration))
            authenticationStatus = .nonAuthenticated
        }
    }

    private func showAlert(with message: String) {
        alertMessage = message
        showAlert = true
    }
}

#Preview {
    VerificationView(
        authenticationStatus: .constant(nil),
        email: "example@email.com",
        requestId: "preview-request-id"
    )
}
