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
        switch checkoutUrlResult {
        case .success(let url):
            CheckoutWebView(url: url)
        case .failure(let error):
            VStack(spacing: 20) {
                Text("Error")
                    .font(.headline)
                Text(error.localizedDescription)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding()
            }
        }
    }
    
    private var checkoutUrlResult: Result<String, Error> {
        Result { try generateCheckoutUrl() }
    }
    
    private func generateCheckoutUrl() throws -> String {
        let baseUrlString = environment == .production
            ? "https://www.crossmint.com/sdk/2024-03-05/embedded-checkout"
            : "https://staging.crossmint.com/sdk/2024-03-05/embedded-checkout"
        
        guard var components = URLComponents(string: baseUrlString) else {
            throw CheckoutError.invalidConfiguration("Invalid base URL")
        }
        
        var queryItems: [URLQueryItem] = []
        
        // TODO: Fetch SDK version dynamically
        let sdkMetadata = ["name": "@crossmint/client-sdk-swift", "version": "1.0.0"]
        queryItems.append(URLQueryItem(name: "sdkMetadata", value: try encodeToJSON(sdkMetadata)))
        
        if let orderId = orderId {
            queryItems.append(URLQueryItem(name: "orderId", value: orderId))
        }
        
        if let clientSecret = clientSecret {
            queryItems.append(URLQueryItem(name: "clientSecret", value: clientSecret))
        }
        
        if let lineItems = lineItems {
            throw CheckoutError.notImplemented("Crossmint Checkout SDK: passing lineItems is not yet implemented")
        }
        
        if let payment = payment {
            queryItems.append(URLQueryItem(name: "payment", value: try encodeToJSON(payment)))
        }
        
        if let recipient = recipient {
            throw CheckoutError.notImplemented("Crossmint Checkout SDK: passing recipient is not yet implemented")
        }
        
        if let appearance = appearance {
            queryItems.append(URLQueryItem(name: "appearance", value: try encodeToJSON(appearance)))
        }
        
        components.queryItems = queryItems
        
        guard let url = components.url?.absoluteString else {
            throw CheckoutError.invalidConfiguration("Failed to construct URL")
        }
        
        print("Checkout URL: \(url)")
        return url
    }
    
    private func encodeToJSON<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        let data = try encoder.encode(value)
        guard let json = String(data: data, encoding: .utf8) else {
            throw CheckoutError.invalidConfiguration("Failed to encode JSON")
        }
        return json
    }
}

public enum CheckoutEnvironment {
    case staging
    case production
}

