import CrossmintClient
import SwiftUI

struct SignInView: View {
    @Binding var authenticationStatus: AuthenticationStatus?

    @State private var navigateToOTP = false
    @State private var navigateToJWT = false
    @State private var opacity: Double = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()

                AuthHeaderView(
                    title: "Smart Wallets Demo",
                    subtitle: "The easiest way to build onchain"
                )

                Spacer()

                VStack(spacing: 12) {
                    Button { navigateToOTP = true } label: {
                        Text("Sign in with Crossmint")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.green)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    Button { navigateToJWT = true } label: {
                        Text("Sign in with your JWT")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .foregroundStyle(.green)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.green, lineWidth: 1))
                    }
                }

                Spacer()

                CrossmintPoweredView()
                    .padding(.bottom, 20)
            }
            .padding(.horizontal, 24)
            .background(Color(.systemBackground))
            .opacity(opacity)
            .onAppear {
                withAnimation(AnimationConstants.easeIn()) { opacity = 1 }
            }
            .navigationDestination(isPresented: $navigateToOTP) {
                OTPSignInView(authenticationStatus: $authenticationStatus)
            }
            .navigationDestination(isPresented: $navigateToJWT) {
                JWTSignInView(authenticationStatus: $authenticationStatus)
            }
        }
    }
}

#Preview {
    SignInView(authenticationStatus: .constant(nil))
}
