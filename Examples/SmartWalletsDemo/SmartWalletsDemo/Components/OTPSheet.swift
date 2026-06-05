//
//  OTPSheet.swift
//  SmartWalletsDemo
//

import CrossmintClient
import SwiftUI

extension View {
    func otpSheet() -> some View {
        modifier(OTPSheetModifier())
    }
}

private struct OTPSheetModifier: ViewModifier {
    @State private var showOTPView = false

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showOTPView, onDismiss: {
                CrossmintSDK.shared.cancelTransaction()
            }) { OTPValidatorView() }
            .onReceive(CrossmintSDK.shared.isOTPRequired) { showOTPView = $0 }
    }
}
