import WebKit

extension WKUserContentController {
    func add(webViewCommunicationProxy: any WebViewCommunicationProxy) {
        add(webViewCommunicationProxy, name: webViewCommunicationProxy.name)
    }
}
