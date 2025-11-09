import Logger
import SwiftUI

#if canImport(CheckoutComponents)
    import CheckoutComponents
#elseif canImport(CheckoutComponentsSDK)
    import CheckoutComponentsSDK
#endif

@MainActor
public final class CheckoutComPaymentFormManager: ObservableObject {
    @Published public private(set) var checkoutComponentsView: AnyView?
    @Published public internal(set) var paymentSucceeded: Bool = false
    @Published var showPaymentResult: Bool = false

    @Published var paymentID: String = ""
    @Published var errorMessage: String = ""

    @Published var isDefaultAppearance = true
    public private(set) var showPayButton = true

    private var component: CheckoutComponents.Actionable?
    internal var processingOrder: Order?

    internal let checkoutComAdapter = CheckoutComAdapter()

    // TODO remove this once checkout.com allows for .submit() to be called on actionable.
    var handleSubmitPayment: () async -> Bool = { return true }

    public init() {}

    public func updateSubmitHandler(_ handler: @escaping () async -> Bool) {
        self.handleSubmitPayment = handler
    }
}

extension CheckoutComPaymentFormManager {
    public func makeComponent(order: Order?, forProductionEnvironment isProduction: Bool) async {
        do {
            guard
                let paymentStage = order?.payment.paymentStage,
                case let .preparation(preparation) = paymentStage,
                case let .checkoutcomOrderPaymentPreparation(checkoutComPreparation) = preparation,
                let paymentSessionId = checkoutComPreparation.checkoutcomPaymentSession?.id,
                let paymentSessionSecret = checkoutComPreparation.checkoutcomPaymentSession?
                    .paymentSessionSecret
            else {
                // TODO either throw or show global message
                errorMessage =
                    "[CheckoutComPaymentFormManager.makeComponent] Cannot retrieve payment session and payment session secret"
                Logger.payments.error(errorMessage)
                return
            }

            let paymentSession: PaymentSession = PaymentSession(
                id: paymentSessionId,
                paymentSessionSecret: paymentSessionSecret)

            let checkoutComponentsSDK = try await initialiseCheckoutComponentsSDK(
                with: paymentSession,
                publicKey: checkoutComPreparation.checkoutcomPublicKey,
                isProduction: isProduction)
            let component = try createComponent(with: checkoutComponentsSDK)
            self.component = component
            let renderedComponent = render(component: component)

            checkoutComponentsView = renderedComponent
            self.processingOrder = order

        } catch let error {
            errorMessage = error.localizedDescription
            Logger.payments.error(error.localizedDescription)
        }
    }
}

extension CheckoutComPaymentFormManager {
    // Step 2: Initialise an instance of Checkout Components SDK
    func initialiseCheckoutComponentsSDK(
        with paymentSession: PaymentSession, publicKey: String, isProduction: Bool
    )
        async throws(CheckoutComponents.Error) -> CheckoutComponents {
        let configuration = try await CheckoutComponents.Configuration(
            paymentSession: paymentSession,
            publicKey: publicKey,
            environment: isProduction ? .production : .sandbox,
            appearance: designToken,
            callbacks: initialiseCallbacks())

        return CheckoutComponents(configuration: configuration)
    }

    // Step 3: Create any component available
    func createComponent(with checkoutComponentsSDK: CheckoutComponents) throws(CheckoutComponents
        .Error) -> any CheckoutComponents.Actionable {
        return try checkoutComponentsSDK.create(
            .card(showPayButton: showPayButton, paymentButtonAction: .payment)
        )
    }

    // Step 4: Render the created component to get the view to be shown
    func render(component: any CheckoutComponents.Actionable) -> AnyView? {
        // Check if component is available first

        if component.isAvailable {
            return component.render()
        } else {
            return nil
        }
    }

    public func submitPayment() {
        component?.tokenize()
    }
}

let designToken: CheckoutComponents.DesignTokens = .init(
    colorTokensMain: colorTokens,
    fonts: .init(
        button: buttonFont,
        input: inputFont,
        label: labelFont,
        subheading: subheadingFont
    ),
    borderButtonRadius: .init(radius: 12),
    borderFormRadius: .init(
        radius: 12
    )
)

let colorTokens: CheckoutComponents.ColorTokens = .init(
    action: Color(hex: "#05B959"),
    border: .white,
    disabled: Color(hex: "#67797F"),
    formBackground: .white,
    formBorder: Color(hex: "#D0D5DD"))

let buttonFont: CheckoutComponents.Font = .init(
    font: .custom("Inter", size: 16),
    lineHeight: 2,
    letterSpacing: 0.5
)

let subheadingFont: CheckoutComponents.Font = .init(
    font: .custom("Inter", size: 16),
    lineHeight: 2,
    letterSpacing: 0.5
)

let inputFont: CheckoutComponents.Font = .init(
    font: .custom("Inter", size: 16),
    lineHeight: 2,
    letterSpacing: 0.5
)

let labelFont: CheckoutComponents.Font = .init(
    font: .custom("Inter", size: 16),
    lineHeight: 2,
    letterSpacing: 0.5
)
