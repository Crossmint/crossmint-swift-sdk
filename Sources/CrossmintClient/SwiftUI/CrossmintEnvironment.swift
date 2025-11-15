import AuthUI
import Logger
import SwiftUI
import Wallet

public protocol NonCustodialSignerCallbackView: View {
    var nonCustodialSignerCallback: NonCustodialSignerCallback { get }
}

extension View {
    public func crossmintEnvironmentObject(
        _ sdk: CrossmintSDK
    ) -> some View {
        ZStack {
            self.environmentObject(sdk)
        }.onAppear {
            Logger.sdk.info("Initializing the environment without non-custodial signers setup. This might cause trouble if a signer of that type is required later on.")
        }
    }

    public func crossmintEnvironmentObject<NCSView: NonCustodialSignerCallbackView>(
        _ sdk: CrossmintSDK,
        @ViewBuilder ncsViewBuilder: (NonCustodialSignerCallback) -> NCSView
    ) -> some View {
        ZStack {
            EmailSignersView(webViewCommunicationProxy: sdk.crossmintTEE.webProxy)

            self.environmentObject(sdk)

            SDKAccessoryView(sdk: sdk) {
                ncsViewBuilder(sdk.crossmintTEE.getCallback())
            }
        }
    }
}

private struct SDKAccessoryView<OTPView: NonCustodialSignerCallbackView>: View {
    @ObservedObject private var crossmintTEE: CrossmintTEE
    private let sdk: CrossmintSDK
    let otpView: OTPView

    init(
        sdk: CrossmintSDK,
        @ViewBuilder otpView: () -> OTPView
    ) {
        self.sdk = sdk
        self.crossmintTEE = sdk.crossmintTEE
        self.otpView = otpView()
    }

    var body: some View {
        ZStack {
            if crossmintTEE.isOTPRequired {
                otpView
            }
        }
    }
}
