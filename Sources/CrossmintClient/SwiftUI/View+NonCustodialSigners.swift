import SwiftUI

private struct CrossmintNonCustodialSignerViewModifier: ViewModifier {
    @ObservedObject private var crossmintTEE: CrossmintTEE
    @Binding private var presentingCallback: NonCustodialSignerCallback?

    init(sdk: CrossmintSDK, presentingCallback: Binding<NonCustodialSignerCallback?>) {
        crossmintTEE = sdk.crossmintTEE
        _presentingCallback = presentingCallback
    }

    func body(content: Content) -> some View {
        ZStack {
            EmailSignersView(
                webViewCommunicationProxy: crossmintTEE.webProxy
            )
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .task {
                try? await crossmintTEE.load()
            }

            content
        }
        .onChange(of: crossmintTEE.isOTPRequired) { newValue in
            if newValue {
                presentingCallback = crossmintTEE.getCallback()
            } else {
                presentingCallback = nil
            }
        }
    }
}

private struct CrossmintNonCustodialSignerSheetModifier<OTPView: NonCustodialSignerCallbackView>: ViewModifier {
    @ObservedObject private var crossmintTEE: CrossmintTEE
    private let otpView: (NonCustodialSignerCallback) -> OTPView

    @State private var callback: NonCustodialSignerCallback?

    init(sdk: CrossmintSDK, @ViewBuilder otpView: @escaping (NonCustodialSignerCallback) -> OTPView) {
        crossmintTEE = sdk.crossmintTEE
        self.otpView = otpView
    }

    func body(content: Content) -> some View {
        ZStack {
            EmailSignersView(
                webViewCommunicationProxy: crossmintTEE.webProxy
            )
            // Keep the web view "hidden"
            .frame(width: 1, height: 1)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .task {
                try? await crossmintTEE.load()
            }

            content
        }
        .onChange(of: crossmintTEE.isOTPRequired) { newValue in
            callback = newValue ? crossmintTEE.getCallback() : nil
        }
        .sheet(item: $callback) { cb in
            otpView(cb)
        }
    }
}

extension View {
    public func crossmintNonCustodialSigners(
        _ sdk: CrossmintSDK,
        presentingCallback: Binding<NonCustodialSignerCallback?>
    ) -> some View {
        self.modifier(
            CrossmintNonCustodialSignerViewModifier(sdk: sdk, presentingCallback: presentingCallback)
        )
    }

    public func crossmintNonCustodialSignersSheet<Content: NonCustodialSignerCallbackView>(
        _ sdk: CrossmintSDK,
        @ViewBuilder otpView: @escaping (NonCustodialSignerCallback) -> Content
    ) -> some View {
        self.modifier(
            CrossmintNonCustodialSignerSheetModifier(sdk: sdk, otpView: otpView)
        )
    }
}
