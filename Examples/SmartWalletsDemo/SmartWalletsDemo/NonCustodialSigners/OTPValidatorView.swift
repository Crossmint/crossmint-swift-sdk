import SwiftUI
import CrossmintClient

struct OTPValidatorView: View {
    let flow: OTPFlow

    @State private var verificationCode = ""
    @State private var isVerifying = false
    @State private var verificationSucceeded = false
    @State private var errorMessage: String?
    @State private var opacity: Double = 0

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

            Text("Code sent to \(flow.email)")
                .font(.caption)
                .foregroundColor(.secondary)

            CustomTextField(
                placeholder: "Verification code",
                text: $verificationCode,
                keyboardType: .numberPad,
                multilineTextAlignment: .center
            )
            .autocapitalization(.none)
            .disableAutocorrection(true)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            PrimaryButton(
                text: verificationSucceeded ? "Verified — signing…" : (isVerifying ? "Verifying…" : "Verify"),
                action: verify,
                isDisabled: verificationCode.isEmpty || isVerifying || verificationSucceeded
            )

            Button("Resend code") { resend() }
                .font(.caption)
                .foregroundColor(.secondary)
                .disabled(verificationSucceeded)

            Spacer()
        }
        .padding(.horizontal, 24)
        .background(Color(.systemBackground))
        .opacity(opacity)
        .onAppear {
            withAnimation(AnimationConstants.easeIn()) { opacity = 1 }
        }
    }

    private func verify() {
        isVerifying = true
        errorMessage = nil
        Task {
            do {
                try await flow.verifyOTP(verificationCode)
                verificationSucceeded = true
            } catch {
                isVerifying = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private func dismiss() {
        flow.cancel()
    }

    private func resend() {
        Task {
            do {
                try await flow.sendOTP()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
