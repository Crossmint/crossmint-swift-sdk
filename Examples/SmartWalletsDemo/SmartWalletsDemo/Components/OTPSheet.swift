//
//  OTPSheet.swift
//  SmartWalletsDemo
//

import CrossmintClient
import SwiftUI

extension View {
    func otpSheet(flow: Binding<OTPFlow?>) -> some View {
        sheet(item: flow) { OTPValidatorView(flow: $0) }
    }
}
