import SwiftUI
import CrossmintClient

struct OTPValidatorView: View {
    let flow: OTPFlow

    @State private var verificationCode = ""
    @State private var isVerifying = false
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

            switch flow.signer {
            case .email(let addr):
                Text("Code sent to \(addr)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            case .phone(let num):
                Text("Code sent to \(num)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

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
                text: isVerifying ? "Verifying…" : "Verify",
                action: verify,
                isDisabled: verificationCode.isEmpty || isVerifying
            )

            Button("Resend code") { resend() }
                .font(.caption)
                .foregroundColor(.secondary)

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
                try await flow.verifyOTP(code: verificationCode)
            } catch {
                errorMessage = error.localizedDescription
                isVerifying = false
            }
        }
    }

    private func dismiss() {
        flow.cancel()
    }

    private func resend() {
        Task { try? await flow.sendOTP() }
    }
}
