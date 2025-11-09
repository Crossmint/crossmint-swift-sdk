import CrossmintService
import Payments
import SwiftUI

public struct EmbeddedCheckoutCompletedView: View {
    @EnvironmentObject var orderManager: HeadlessCheckoutOrderManager

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                EmbeddedCheckoutCompletedHeaderView().padding(.bottom, 8)
                EmbeddedCheckoutLineContentsView()
                EmbeddedCheckoutOrderDetailsView()

                Divider()
                EmbeddedCheckoutDeliveryAndPaymentView()
                    .padding(.bottom, 8)

                EmbeddedCheckoutOpenInCrossmintButton()
                    .padding(.bottom)
            }
            .padding(.horizontal)
        }
        .task {
            orderManager.isPolling = false
        }
    }
}

#Preview {
    // JSON order
    let json = """
        {
            "phase" : "completed",
            "locale" : "en-US",
            "orderId" : "1e835c95-9065-42a1-aa68-77a2753f20b4",
            "lineItems" : [
                {
                "chain" : "base-sepolia",
                "quantity" : 1,
                "delivery" : {
                    "status" : "completed",
                    "recipient" : {
                    "locator" : "email:test@paella.dev:base-sepolia",
                    "email" : "test@paella.dev",
                    "walletAddress" : "0x7ECC059122762aBd66D70eC0e014bd46F18Fc57A"
                    },
                    "tokens" : [
                    {
                        "locator" : "base-sepolia:0x3B4aD5a1b6199c8905d5F3272ae618bFCb35067c:7",
                        "contractAddress" : "0x3B4aD5a1b6199c8905d5F3272ae618bFCb35067c",
                        "tokenId" : "7"
                    }
                    ],
                    "txId" : "0xde4307b3cd2b4dabff270b6e5ad27bb608b4e3a2ca738bf1bd0ae3a4fa0fad60"
                },
                "executionMode" : "exact-out",
                "metadata" : {
                    "name" : "My nft",
                    "imageUrl" : "https://lh3.googleusercontent.com/K3jRCmDa1i11JfzUAegOk_LYwNFfbShz5ljBV8Prs4qSubHx437tO5M8KUaQ7A5JotzzNxW5N-PAp_H_8IuoCkWpmysGh31fFeEn=s1000",
                    "description" : "badd descre"
                },
                "callData" : {
                    "quantity" : 1
                },
                "quote" : {
                    "status" : "valid",
                    "charges" : {
                    "unit" : {
                        "amount" : "0.7",
                        "currency" : "usd"
                    }
                    },
                    "totalPrice" : {
                    "amount" : "0.7",
                    "currency" : "usd"
                    }
                }
                }
            ],
            "payment" : {
                "status" : "completed",
                "currency" : "usd",
                "method" : "checkoutcom-flow",
                "received" : {
                "amount" : "0.7",
                "currency" : "usd"
                },
                "receiptEmail" : "test@paella.dev",
                "preparation" : {
                "checkoutcomPaymentSession" : {
                    "id" : "ps_2vBfya7uqPzkoeWDRtwq7ZQE4X4",
                    "payment_session_token" : "test",
                    "payment_session_secret" : "test",
                    "_links" : {
                    "self" : {
                        "href" : "https://api.sandbox.checkout.com/payment-sessions/ps_2vBfya7uqPzkoeWDRtwq7ZQE4X4"
                    }
                    }
                },
                "checkoutcomPublicKey" : "test"
                }
            },
            "quote" : {
                "status" : "valid",
                "quotedAt" : "2025-04-02T19:53:59.295Z",
                "expiresAt" : "2025-04-02T20:03:59.295Z",
                "totalPrice" : {
                "amount" : "0.7",
                "currency" : "usd"
                }
            }
            }
        """
    if let data = json.data(using: .utf8),
        let order = try? DefaultJSONCoder().decode(Order.self, from: data) {
        let checkoutStateManager = EmbeddedCheckoutStateManager(
            paymentMethod: .card,
            receiptEmail: "test@paella.dev"
        )
        if let apiKey = try? ApiKey(key: "ck_test_1234567890") {
            let crossmintService = DefaultCrossmintService(apiKey: apiKey, appIdentifier: "")
            let orderManager = HeadlessCheckoutOrderManager(
                crossmintService: crossmintService,
                checkoutStateManager: checkoutStateManager,
                order: order
            )

            EmbeddedCheckoutCompletedView()
                .environmentObject(orderManager)
                .environmentObject(checkoutStateManager)
        }
    }
}
