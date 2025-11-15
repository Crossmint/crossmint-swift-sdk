import CrossmintClient
import Payments
import PaymentsUI
import SwiftUI

public struct EmbeddedCompletedView: View {
    @StateObject private var orderManager: HeadlessCheckoutOrderManager

    // swiftlint:disable:next function_body_length
    public init() {
        // JSON order
        let json = """
            {
                "phase" : "completed",
                "locale" : "en-US",
                "orderId" : "b2fdd923-c7af-4213-8957-2602c8296918",
                "lineItems" : [
                    {
                    "chain" : "base-sepolia",
                    "quantity" : 1,
                    "delivery" : {
                        "status" : "failed",
                        "failureReason": {
                            "code": "slippage-tolerance-exceeded"
                        },
                        "recipient" : {
                        "locator" : "base-sepolia:0xD667ae8a23b89BfE539a0f8E09D005Aa5CEFfD00",
                        "walletAddress" : "0xD667ae8a23b89BfE539a0f8E09D005Aa5CEFfD00",
                        "physicalAddress" : null
                        },
                        "tokens" : [
                        {
                            "locator" : "base-sepolia:0x34113652Ec96bC13669C95b80a4be6D0CfAaceCa:1",
                            "contractAddress" : "0x34113652Ec96bC13669C95b80a4be6D0CfAaceCa",
                            "tokenId" : "1"
                        }
                        ],
                        "txId" : "0xab361133707eb405dabad42475fa9d78a28145e9c15632d5d53c57ed60dd8afe"
                    },
                    "executionMode" : "exact-out",
                    "metadata" : {
                        "name" : "Swofty",
                        "imageUrl" : "https://lh3.googleusercontent.com/COOQwNYS5nM718SQ2c3GPgI6XdXX6ILW5JtCIs1drYlT4sU7ZfFPdh1qQiVlaMas9L-MSpcnI1lNOobXs9MbFg2myVDLlPNSkQM=s1000",
                        "description" : "Wow a swift sdk collection"
                    },
                    "callData" : {
                        "quantity" : 1
                    },
                    "quote" : {
                        "status" : "valid",
                        "charges" : {
                        "unit" : {
                            "amount" : "1.35",
                            "currency" : "usd"
                        }
                        },
                        "totalPrice" : {
                        "amount" : "1.35",
                        "currency" : "usd"
                        }
                    }
                    },
                    {
                    "chain" : "base-sepolia",
                    "quantity" : 1,
                    "delivery" : {
                        "status" : "failed",
                        "recipient" : {
                        "locator" : "base-sepolia:0xD667ae8a23b89BfE539a0f8E09D005Aa5CEFfD00",
                        "walletAddress" : "0xD667ae8a23b89BfE539a0f8E09D005Aa5CEFfD00",
                        "physicalAddress" : null
                        },
                        "tokens" : [
                        {
                            "locator" : "base-sepolia:0x34113652Ec96bC13669C95b80a4be6D0CfAaceCa:2",
                            "contractAddress" : "0x34113652Ec96bC13669C95b80a4be6D0CfAaceCa",
                            "tokenId" : "2"
                        }
                        ],
                        "txId" : "0x673782dd34b59f7ecc839d41b99b06c2079871abcd3137808e6d21a6de518074"
                    },
                    "executionMode" : "exact-out",
                    "metadata" : {
                        "name" : "Swofty",
                        "imageUrl" : "https://lh3.googleusercontent.com/COOQwNYS5nM718SQ2c3GPgI6XdXX6ILW5JtCIs1drYlT4sU7ZfFPdh1qQiVlaMas9L-MSpcnI1lNOobXs9MbFg2myVDLlPNSkQM=s1000",
                        "description" : "Wow a swift sdk collection"
                    },
                    "callData" : {
                        "quantity" : 1
                    },
                    "quote" : {
                        "status" : "valid",
                        "charges" : {
                        "unit" : {
                            "amount" : "1.35",
                            "currency" : "usd"
                        }
                        },
                        "totalPrice" : {
                        "amount" : "1.35",
                        "currency" : "usd"
                        }
                    }
                    },
                    {
                    "chain" : "base-sepolia",
                    "quantity" : 1,
                    "delivery" : {
                        "status" : "failed",
                        "recipient" : {
                        "locator" : "base-sepolia:0xD667ae8a23b89BfE539a0f8E09D005Aa5CEFfD00",
                        "walletAddress" : "0xD667ae8a23b89BfE539a0f8E09D005Aa5CEFfD00",
                        "physicalAddress" : null
                        },
                        "tokens" : [
                        {
                            "locator" : "base-sepolia:0x34113652Ec96bC13669C95b80a4be6D0CfAaceCa:4",
                            "contractAddress" : "0x34113652Ec96bC13669C95b80a4be6D0CfAaceCa",
                            "tokenId" : "4"
                        }
                        ],
                        "txId" : "0x35fa441681ce4df569dd81e9a22fb8fb62ecbe7ec5f61fa3711c65286db4b4ad"
                    },
                    "executionMode" : "exact-out",
                    "metadata" : {
                        "name" : "Swofty",
                        "imageUrl" : "https://lh3.googleusercontent.com/COOQwNYS5nM718SQ2c3GPgI6XdXX6ILW5JtCIs1drYlT4sU7ZfFPdh1qQiVlaMas9L-MSpcnI1lNOobXs9MbFg2myVDLlPNSkQM=s1000",
                        "description" : "Wow a swift sdk collection"
                    },
                    "callData" : {
                        "quantity" : 1
                    },
                    "quote" : {
                        "status" : "valid",
                        "charges" : {
                        "unit" : {
                            "amount" : "1.35",
                            "currency" : "usd"
                        }
                        },
                        "totalPrice" : {
                        "amount" : "1.35",
                        "currency" : "usd"
                        }
                    }
                    },
                    {
                    "chain" : "base-sepolia",
                    "quantity" : 1,
                    "delivery" : {
                        "status" : "failed",
                        "recipient" : {
                        "locator" : "base-sepolia:0xD667ae8a23b89BfE539a0f8E09D005Aa5CEFfD00",
                        "walletAddress" : "0xD667ae8a23b89BfE539a0f8E09D005Aa5CEFfD00",
                        "physicalAddress" : null
                        },
                        "tokens" : [
                        {
                            "locator" : "base-sepolia:0x34113652Ec96bC13669C95b80a4be6D0CfAaceCa:3",
                            "contractAddress" : "0x34113652Ec96bC13669C95b80a4be6D0CfAaceCa",
                            "tokenId" : "3"
                        }
                        ],
                        "txId" : "0xe93894ac7111fb01bc742cf615f3d65fe8eb41d2497d9dcbc25ab3a7c72621e5"
                    },
                    "executionMode" : "exact-out",
                    "metadata" : {
                        "name" : "Swofty",
                        "imageUrl" : "https://lh3.googleusercontent.com/COOQwNYS5nM718SQ2c3GPgI6XdXX6ILW5JtCIs1drYlT4sU7ZfFPdh1qQiVlaMas9L-MSpcnI1lNOobXs9MbFg2myVDLlPNSkQM=s1000",
                        "description" : "Wow a swift sdk collection"
                    },
                    "callData" : {
                        "quantity" : 1
                    },
                    "quote" : {
                        "status" : "valid",
                        "charges" : {
                        "unit" : {
                            "amount" : "1.35",
                            "currency" : "usd"
                        }
                        },
                        "totalPrice" : {
                        "amount" : "1.35",
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
                    "amount" : "5.4",
                    "currency" : "usd"
                    },
                    "receiptEmail" : "test@paella.dev",
                    "preparation" : {
                    "checkoutcomPaymentSession" : {
                        "id" : "ps_2vQA9O0dqW9T3YvPk8WNy6KCUmr",
                        "payment_session_token" : "test",
                        "payment_session_secret" : "test",
                        "_links" : {
                        "self" : {
                            "href" : "https://api.sandbox.checkout.com/payment-sessions/ps_2vQA9O0dqW9T3YvPk8WNy6KCUmr"
                        }
                        }
                    },
                    "checkoutcomPublicKey" : "pk_sbox_oc4txzlixkh5fxlgxqofjwvtzmg"
                    }
                },
                "quote" : {
                    "status" : "valid",
                    "quotedAt" : "2025-04-07T22:59:30.761Z",
                    "expiresAt" : "2025-04-07T23:09:30.733Z",
                    "totalPrice" : {
                    "amount" : "5.4",
                    "currency" : "usd"
                    }
                }
                }

            """

        // Set up initial objects
        let checkoutStateManager = EmbeddedCheckoutStateManager(
            paymentMethod: .card,
            receiptEmail: "test@paella.dev"
        )

        var order: Order?
        if let jsonData = json.data(using: .utf8) {
            do {
                order = try DefaultJSONCoder().decode(Order.self, from: jsonData)
                // swiftlint:disable:next force_unwrapping
                print("[EmbeddedCompletedView] Order parsed: \(order!.json(prettyPrinted: true))")
            } catch {
                print("[EmbeddedCompletedView] Decoding error: \(error)")
            }
        } else {
            print("[EmbeddedCompletedView] Error: Could not convert JSON string to data")
        }

        let orderManager = HeadlessCheckoutOrderManager(
            crossmintService: CrossmintSDK.shared.crossmintService,
            checkoutStateManager: checkoutStateManager,
            order: order
        )

        self._orderManager = StateObject(wrappedValue: orderManager)
    }

    public var body: some View {
        EmbeddedCheckoutCompletedView().environmentObject(orderManager)
    }
}
