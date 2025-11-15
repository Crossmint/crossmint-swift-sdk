import Logger
import SwiftUI
import Web
public struct EmailSignersView: View {
    private let webViewCommunicationProxy: WebViewCommunicationProxy

    public init(webViewCommunicationProxy: WebViewCommunicationProxy) {
        self.webViewCommunicationProxy = webViewCommunicationProxy
    }

    public var body: some View {
        VStack {
            CrossmintWebView(
                webViewCommunicationProxy: webViewCommunicationProxy
            )
        }
    }
}
