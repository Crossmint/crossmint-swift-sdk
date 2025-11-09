import CrossmintService
import Foundation
import Http
import Logger
import SwiftUI
import Utils

@MainActor
public final class HeadlessCheckoutOrderManager: @unchecked Sendable, AuthenticatedService,
    ObservableObject {
    @Published private(set) public var order: Order?
    @Published private(set) public var isGettingOrder: Bool = false
    @Published private(set) public var isCreatingOrder: Bool = false
    @Published private(set) public var isUpdatingOrder: Bool = false
    @Published private(set) public var secondsUntilQuoteRefresh: Int = 0
    @Published public var isPolling: Bool = false {
        didSet {
            if isPolling != oldValue {
                if isPolling {
                    startPolling()
                } else {
                    stopPolling()
                }
            }
        }
    }

    private let getOrderPollingInterval: TimeInterval = 3.0
    private let refreshQuoteBufferSeconds: TimeInterval = 2.0
    private var clientSecret: String?
    private var pollingTimer: Timer?
    private var quoteRefreshTimer: Timer?
    private var isRefreshingOrder: Bool = false

    private let crossmintService: CrossmintService
    private let orderService: HeadlessOrderService
    private let checkoutStateManager: any CheckoutStateManager

    public var authHeaders: [String: String] {
        guard let clientSecret = clientSecret else {
            return [:]
        }

        return [
            "authorization": clientSecret
        ]
    }

    public var isProductionEnvironment: Bool {
        crossmintService.isProductionEnvironment
    }

    public init(
        crossmintService: CrossmintService, checkoutStateManager: any CheckoutStateManager,
        order: Order? = nil
    ) {
        self.crossmintService = crossmintService
        self.orderService = HeadlessOrderService(crossmintService: crossmintService)
        self.checkoutStateManager = checkoutStateManager
        self.order = order
    }

    public func getOrder(
        specificOrderId: String? = nil
    ) async throws(OrderError) -> Order {
        isGettingOrder = true
        defer { isGettingOrder = false }

        let orderId = specificOrderId ?? order?.orderIdString
        guard let orderId = orderId, !orderId.isEmpty else {
            Logger.payments.warn(
                "[HeadlessOrderManager] getOrder called before order is created. Ignoring get request."
            )
            throw OrderError.orderNotCreated
        }

        Logger.payments.info("[HeadlessOrderManager] getOrder \(orderId)")

        do {
            let order = try await orderService.fetchOrder(
                orderId: orderId, authHeaders: authHeaders)
            self.order = order
            handleOrderSuccess(order)
            return order
        } catch {
            handleNetworkError(
                error, message: "Failed to get order", checkoutOrderMethod: .getOrder)
            throw error
        }
    }

    public func createOrder(
        input: HeadlessCheckoutCreateOrderInput
    ) async throws -> HeadlessCheckoutCreateOrderResponse {
        isCreatingOrder = true
        defer { isCreatingOrder = false }

        Logger.payments.info("[HeadlessOrderManager] createOrder \(input)")

        do {
            let result = try await orderService.createOrder(input: input)
            Logger.payments.info(
                "[HeadlessOrderManager] createOrder order result: \(result.order.json(prettyPrinted: true))"
            )
            self.order = result.order
            self.clientSecret = result.clientSecret
            handleOrderSuccess(result.order)
            setLocalStatePaymentModality(paymentStage: result.order.payment.paymentStage)
            return result
        } catch {
            handleNetworkError(
                error, message: "Failed to create order", checkoutOrderMethod: .createOrder)
            throw error
        }
    }

    public func updateOrder(
        input: HeadlessCheckoutUpdateOrderInput
    ) async throws(OrderError) -> Order {
        isUpdatingOrder = true
        defer { isUpdatingOrder = false }

        guard let order = order else {
            Logger.payments.warn(
                "[HeadlessOrderManager] updateOrder called before order is created. Ignoring update request."
            )
            throw OrderError.orderNotCreated
        }

        Logger.payments.info("[HeadlessOrderManager] updateOrder \(input)")

        let orderIdCopy = order.orderIdString

        do {
            let updatedOrder = try await orderService.updateOrder(
                orderId: orderIdCopy,
                input: input,
                authHeaders: authHeaders
            )
            self.order = updatedOrder

            handleOrderSuccess(updatedOrder)
            return updatedOrder
        } catch {
            handleNetworkError(
                error, message: "Failed to update order", checkoutOrderMethod: .updateOrder)
            throw error
        }
    }

    public func processCryptoPayment(
        txId: String
    ) async throws(OrderError) -> Order {
        guard let orderId = order?.orderIdString, !isEmpty(orderId) else {
            Logger.payments.warn(
                "[HeadlessOrderManager] processCryptoPayment called before order is created. Ignoring post request."
            )
            throw OrderError.orderNotCreated
        }

        Logger.payments.info("[HeadlessOrderManager] processCryptoPayment \(orderId)")

        do {
            let updatedOrder = try await orderService.processCryptoPayment(
                orderId: orderId,
                txId: txId,
                authHeaders: authHeaders
            )
            self.order = updatedOrder
            handleOrderSuccess(updatedOrder)
            return updatedOrder
        } catch {
            handleNetworkError(
                error, message: "Failed to process crypto payment",
                checkoutOrderMethod: .processCryptoPayment)
            throw error
        }
    }

    public func refreshOrder() async throws -> Order {
        guard let orderId = order?.orderIdString, !isEmpty(orderId) else {
            Logger.payments.warn(
                "[HeadlessOrderManager] refreshOrder called before order is created. Ignoring refresh request."
            )
            throw OrderError.orderNotCreated
        }

        isPolling = true
        secondsUntilQuoteRefresh = 0
        defer { isPolling = false }

        do {
            let refreshedOrder = try await orderService.refreshOrder(
                orderId: orderId,
                authHeaders: authHeaders
            )
            self.order = refreshedOrder
            handleOrderSuccess(refreshedOrder)
            return refreshedOrder
        } catch {
            Logger.payments.error(
                "[HeadlessCheckoutOrderManager] Failed to refresh order: \(error)")
            throw error
        }
    }

    private func handleOrderSuccess(_ order: Order) {
        scheduleQuoteRefreshIfNeeded()
        handleOrderErrors(order)
    }

    private func handleOrderErrors(_ order: Order) {
        if order.lineItems.allSatisfy(\.isUnavailable) {
            guard order.lineItems.first?.unavailabilityReason != nil else {
                Logger.payments.error(
                    "[OrderInitializer] Unavailability reason not found for order \(order.orderId)")
                return
            }

            checkoutStateManager.globalMessage = EmbeddedCheckoutGlobalMessage(
                message: order.lineItems.first?.unavailabilityReason?.message ?? "",
                displayLocation: .top, type: .error, fatal: true)
        }
    }

    private func handleNetworkError(
        _ error: OrderError, message: String, checkoutOrderMethod: HeadlessCheckoutOrderMethod
    ) {
        Logger.payments.error(
            "[HeadlessOrderManager.handleNetworkError] \(checkoutOrderMethod): message: \(message) failed with error: \(error)"
        )
        checkoutStateManager.globalMessage = EmbeddedCheckoutGlobalMessage(
            message: error.errorMessage,
            displayLocation: .top,
            type: .error,
            fatal: checkoutOrderMethod == .createOrder
        )
    }

    private func isRefreshableOrder(_ order: Order) -> Bool {
        let refreshablePaymentStatuses: [OrderPaymentStatus] = [
            .requiresQuote,
            .requiresCryptoPayerAddress,
            .requiresEmail,
            .cryptoPayerInsufficientFunds,
            .awaitingPayment
        ]

        return refreshablePaymentStatuses.contains(order.payment.status)
    }

    private func startPolling() {
        stopPolling()  // Ensure we don't have multiple timers running

        pollingTimer = Timer.scheduledTimer(
            withTimeInterval: getOrderPollingInterval, repeats: true
        ) { [weak self] _ in
            Task { [weak self] in
                guard let self = self else { return }
                do {
                    _ = try await self.getOrder()
                } catch {
                    Logger.payments.error("[HeadlessOrderManager] Error polling order: \(error)")
                }
            }
        }
    }

    private func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    private func scheduleQuoteRefreshIfNeeded() {
        // Cancel any existing timer first
        cancelQuoteRefreshTimer()

        // Ensure we have an order
        guard let order = order else {
            Logger.payments.warn(
                "[HeadlessOrderManager] Cannot schedule quote refresh: no order exists")
            return
        }

        // Check if the order is refreshable
        guard isRefreshableOrder(order) else {
            Logger.payments.info(
                "[HeadlessOrderManager] Order \(order.orderId) is not refreshable, skipping quote refresh scheduling"
            )
            secondsUntilQuoteRefresh = 0
            return
        }

        // Ensure we have an expiry date
        guard let expiryDate = order.quote.expiresAt else {
            Logger.payments.warn(
                "[HeadlessOrderManager] No expiresAt found for order \(order.orderId)")
            return
        }

        // Calculate time until refresh
        let now = Date()
        let timeUntilExpiry = expiryDate.timeIntervalSince(now)
        let refreshBufferInterval = refreshQuoteBufferSeconds

        let timeUntilRefresh = max(0, timeUntilExpiry - refreshBufferInterval)
        secondsUntilQuoteRefresh = Int(ceil(timeUntilRefresh))

        Logger.payments.info(
            // swiftlint:disable:next line_length
            "[HeadlessOrderManager.scheduleQuoteRefreshIfNeeded] Quote for order \(order.orderId) expires in \(secondsUntilQuoteRefresh) seconds, scheduling refresh"
        )

        // Schedule timer to refresh the quote
        quoteRefreshTimer = Timer.scheduledTimer(withTimeInterval: timeUntilRefresh, repeats: false) { [weak self] _ in
            // Create a new Task to handle the async work
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                // Check if a submission is in progress
                if self.checkoutStateManager.submitInProgress {
                    Logger.payments.info(
                        "[HeadlessOrderManager.scheduleQuoteRefreshIfNeeded] Order payment is being submitted, skipping refresh"
                    )
                    return
                }

                // Get the current order again to ensure it's still refreshable
                guard let currentOrder = self.order, self.isRefreshableOrder(currentOrder) else {
                    Logger.payments.info(
                        "[HeadlessOrderManager.scheduleQuoteRefreshIfNeeded] Order is no longer refreshable, skipping refresh"
                    )
                    return
                }

                Logger.payments.info(
                    // swiftlint:disable:next line_length
                    "[HeadlessOrderManager.scheduleQuoteRefreshIfNeeded] Quote about to expire for order \(currentOrder.orderId), refreshing quote..."
                )

                // Perform the refresh
                self.isRefreshingOrder = true
                do {
                    _ = try await self.refreshOrder()
                } catch {
                    Logger.payments.error(
                        "[HeadlessOrderManager.scheduleQuoteRefreshIfNeeded] Error refreshing order: \(error)"
                    )
                }
                self.isRefreshingOrder = false
            }
        }
    }

    private func cancelQuoteRefreshTimer() {
        quoteRefreshTimer?.invalidate()
        quoteRefreshTimer = nil
    }

    private func setLocalStatePaymentModality(paymentStage: OrderPaymentStage) {
        // If in preparation stage, check if the payment provider is stripe
        guard case .preparation(let paymentPreparation) = paymentStage,
            case .stripeOrderPaymentPreparation(let stripePaymentPreparation) = paymentPreparation
        else {
            return
        }

        // If the payment provider is stripe, check if the subscription id is present
        if !isEmpty(stripePaymentPreparation.stripeSubscriptionId) {
            checkoutStateManager.paymentModality = .subscription
        } else {
            checkoutStateManager.paymentModality = .oneOff
        }
    }
}
