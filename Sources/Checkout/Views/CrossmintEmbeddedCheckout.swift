//
//  CrossmintEmbeddedCheckout.swift
//  Crossmint SDK
//
//  Simplified embedded checkout component using webview
//

import SwiftUI

public struct CrossmintEmbeddedCheckout: View {
    private let orderId: String?
    private let clientSecret: String?
    private let lineItems: CheckoutLineItems?
    private let payment: CheckoutPayment?
    private let recipient: CheckoutRecipient?
    private let apiKey: String?
    private let appearance: CheckoutAppearance?
    private let environment: CheckoutEnvironment
    
    @State private var checkoutUrl: String?
    @State private var errorMessage: String?
    
    public init(
        orderId: String? = nil,
        clientSecret: String? = nil,
        lineItems: CheckoutLineItems? = nil,
        payment: CheckoutPayment? = nil,
        recipient: CheckoutRecipient? = nil,
        apiKey: String? = nil,
        appearance: CheckoutAppearance? = nil,
        environment: CheckoutEnvironment = .staging
    ) {
        self.orderId = orderId
        self.clientSecret = clientSecret
        self.lineItems = lineItems
        self.payment = payment
        self.recipient = recipient
        self.apiKey = apiKey
        self.appearance = appearance
        self.environment = environment
    }
    
    public var body: some View {
        Group {
            if let error = errorMessage {
                VStack(spacing: 20) {
                    Text("Error")
                        .font(.headline)
                    Text(error)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            } else if let url = checkoutUrl {
                CheckoutWebView(url: url)
            } else {
                ProgressView("Loading checkout...")
            }
        }
        .task {
            await loadCheckout()
        }
    }
    
    private func loadCheckout() async {
        do {
            let url = try generateCheckoutUrl()
            checkoutUrl = url
        } catch {
            errorMessage = "Failed to load checkout: \(error.localizedDescription)"
        }
    }
    
    private func generateCheckoutUrl() throws -> String {
        let baseUrl = environment == .production
            ? "https://www.crossmint.com/sdk/2024-03-05/embedded-checkout"
            : "https://staging.crossmint.com/sdk/2024-03-05/embedded-checkout"
        
        let sdkMetadata = ["name": "@crossmint/client-sdk-swift", "version": "1.0.0"]
        
        var queryParams = [
            "sdkMetadata=\(try jsonToURLParam(sdkMetadata))"
        ]
        
        if let orderId = orderId {
            queryParams.append("orderId=\(orderId)")
        }
        
        if let clientSecret = clientSecret {
            queryParams.append("clientSecret=\(clientSecret)")
        }
        
        if let lineItems = lineItems {
            queryParams.append("lineItems=\(try jsonToURLParam(lineItems.toDictionary()))")
        }
        
        if let payment = payment {
            queryParams.append("payment=\(try jsonToURLParam(payment.toDictionary()))")
        }
        
        if let recipient = recipient {
            queryParams.append("recipient=\(try jsonToURLParam(recipient.toDictionary()))")
        }
        
        if let appearance = appearance {
            let appearanceDict = appearance.toDictionary()
            if !appearanceDict.isEmpty {
                queryParams.append("appearance=\(try jsonToURLParam(appearanceDict))")
            }
        }
        
        let url = "\(baseUrl)?" + queryParams.joined(separator: "&")
        return url
    }
    
    private func jsonToURLParam(_ object: Any) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.withoutEscapingSlashes])
        let json = String(data: data, encoding: .utf8)!
        return encodeQueryValue(json)
    }
    
    private func encodeQueryValue(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}

public enum CheckoutEnvironment {
    case staging
    case production
}

