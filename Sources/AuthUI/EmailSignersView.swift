import Logger
import SwiftUI
import Web

public struct EmailSignersView: View {
    private let tee: CrossmintTEE

    public init(tee: CrossmintTEE) {
        self.tee = tee
    }

    public var body: some View {
        VStack {
            CrossmintWebView(tee: tee)
        }
    }
}
